"""Every song of the GB build against the NES sound file (NSF), voice by voice.
NES: build/nsfrender (libgme) renders each NSF track with one voice at a time. GB: the build
with only that GB channel routed (env GB_SND_MASK test builds snd11 / snd22 / snd44 / snd88)
plays the same song, started by setting FF1's song variable ($4B = $40 + track) while standing
on the field. Per voice: frames where the NES voice sounds but the GB one does not (and the
reverse), pitch agreement (cents) and loudness-envelope correlation, after aligning the two.
usage: PYTHONPATH=build/emu sndcmp.py NSF NES_ROM [TRACKS] [SECONDS]
(the four single-channel GB builds must exist: build/snd{11,22,44,88}.gb)"""
import os, sys, subprocess, wave, tempfile
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, '..', '..')
VOICES = [('pulse 1', '11'), ('pulse 2', '22'), ('triangle', '44'), ('noise', '88')]
START = 3700            # NES frame where the song is set (standing on the field after the new game)


def load(path):
    w = wave.open(path); sr = w.getframerate(); ch = w.getnchannels()
    x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(float)
    if ch == 2: x = x.reshape(-1, 2).mean(axis=1)
    if sr > 100000:
        d = 44; x = x[:len(x) // d * d].reshape(-1, d).mean(axis=1); sr = sr / d
    return x, sr


def frames(x, sr, n):
    spf = sr / 60.0
    out = []
    for k in range(n):
        seg = x[int(k * spf):int((k + 1) * spf)]
        out.append(seg - seg.mean() if len(seg) else np.zeros(1))
    return out


def pitch(seg, sr):
    if len(seg) < 64 or np.abs(seg).max() < 1e-6: return 0.0
    N = 1 << 15; s = np.abs(np.fft.rfft(seg * np.hanning(len(seg)), N)); f = np.fft.rfftfreq(N, 1 / sr)
    m = (f > 30) & (f < 5000); sm, fm = s[m], f[m]
    i = np.where(sm > 0.3 * sm.max())[0][0]
    while i + 1 < len(sm) and sm[i + 1] > sm[i]: i += 1
    return fm[i]


def gb_record(gb, track, secs, out):
    sc = '_%d' % (secs * 60 + 200)
    cmd = [sys.executable, os.path.join(HERE, 'sgbshots.py'), NES_ROM, gb, out + '.png', str(START + secs * 60 + 60),
           '--field', sc, '--poke', '004B=%02X' % (0x40 | track), '--poke-at', str(START), '--gambatte',
           '--wav', out, '--wav-from', str(START - 60)] + (['--dmg'] if os.environ.get('SND_DMG') else [])
    subprocess.run(cmd, capture_output=True, env=dict(os.environ))


def main():
    global NES_ROM
    nsf, NES_ROM = sys.argv[1], sys.argv[2]
    tracks = [int(t) for t in sys.argv[3].split(',')] if len(sys.argv) > 3 else list(range(1, 24))
    secs = int(sys.argv[4]) if len(sys.argv) > 4 else 15
    tmp = tempfile.mkdtemp()
    for t in tracks:
        print('track %d' % t)
        for v, (name, mask) in enumerate(VOICES):
            ref = os.path.join(tmp, 'n%d_%d.wav' % (t, v)); gbw = os.path.join(tmp, 'g%d_%d.wav' % (t, v))
            subprocess.run([os.path.join(ROOT, 'build', 'nsfrender'), nsf, str(t), str(secs + 2), ref, str(v)], check=True)
            gb_record(os.path.join(ROOT, 'build', 'snd%s.gb' % mask), t, secs, gbw)
            xn, srn = load(ref); xg, srg = load(gbw)
            nf = secs * 60
            fn = frames(xn, srn, nf); 
            ln = np.array([np.sqrt(np.mean(s ** 2)) for s in fn])
            # GB: the song starts a few frames after the poke: align by the envelope
            gskip = 0
            fg_all = frames(xg[gskip:], srg, nf + 120)
            lg_all = np.array([np.sqrt(np.mean(s ** 2)) for s in fg_all])
            if ln.max() == 0:
                print('  %-9s NES silent; GB %s' % (name, 'silent' if lg_all.max() < 1 else 'sounds'))
                continue
            best = max(range(0, 120), key=lambda L: np.corrcoef(ln, lg_all[L:L + nf])[0, 1] if lg_all[L:L + nf].std() > 0 else -2)
            lg = lg_all[best:best + nf]; fg = fg_all[best:best + nf]
            on_n = ln > 0.02 * ln.max(); on_g = lg > 0.02 * max(lg.max(), 1e-9)
            if os.environ.get('SND_DETAIL') == name.replace(' ', ''):
                print('    aligned lag %d; NES-only frames %s; GB-only %s' % (best, list(np.where(on_n & ~on_g)[0][:30]), list(np.where(~on_n & on_g)[0][:30])))
            corr = np.corrcoef(ln, lg)[0, 1] if lg.std() > 0 else 0
            cents = []
            for k in range(0, nf - 4, 4):
                if on_n[k:k + 4].all() and on_g[k:k + 4].all():
                    a = pitch(np.concatenate(fn[k:k + 4]), srn); b = pitch(np.concatenate(fg[k:k + 4]), srg)
                    if a and b:
                        cents.append(1200 * np.log2(b / a))
                        if os.environ.get('SND_DETAIL') == name.replace(' ', '') and abs(cents[-1]) > 50:
                            print('    frame %d: NES %.0f Hz, GB %.0f Hz' % (k, a, b))
            cents = np.array(cents)
            off = (np.abs(cents) > 50).mean() * 100 if len(cents) else 0
            print('  %-9s sounding NES %4d GB %4d | NES-only %4d GB-only %4d | envelope corr %.2f | pitch off >50c %4.1f%% (median %+.0f)' % (
                name, on_n.sum(), on_g.sum(), (on_n & ~on_g).sum(), (~on_n & on_g).sum(), corr, off, np.median(cents) if len(cents) else 0))
        sys.stdout.flush()


if __name__ == '__main__':
    main()
