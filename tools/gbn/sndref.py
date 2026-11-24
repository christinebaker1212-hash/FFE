"""NES reference audio for the native build's sound checks (owner, 2026-11-24: the audio must be
100% like the NES on DMG and CGB).

NES: cynes plays the user's NES ROM to the field (the new-game script), song T is started as FF1
does ($4B = $40 + T) and the APU register writes are taken frame by frame; an NES APU model
renders them (pulse duty sequencers with their phase kept across notes, constant volume /
envelope, sweep and its mute rule, length counters, the triangle with its linear counter and
phase, the noise LFSR with the NTSC period table, the NES's non-linear mixer).
GB: SameBoy (build/sbsh) plays the same song from a save state on the field: the native build's
song variable (NES_RAM + $4B = $DE4B) set the same way; its 48 kHz output recorded.

usage: PYTHONPATH=build/emu python3 tools/gbn/sndref.py nes NES_ROM TRACK FRAMES OUT.wav [MASK]
       python3 tools/gbn/sndref.py gb GB_ROM STATE MODEL TRACK FRAMES OUT.wav [NR51]
MASK: channels rendered (bits 0-3: pulse 1, pulse 2, triangle, noise; default all)
Nothing here holds game data: the music comes from the ROM given, at run time."""
import os, sys, wave, subprocess
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, '..', '..')
CPU = 1789773.0
SR = 48000
FRAME_CYC = 29780.5
LEN = [10, 254, 20, 2, 40, 4, 80, 6, 160, 8, 60, 10, 14, 12, 26, 14,
       12, 16, 24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30]
DUTY = [[0, 1, 0, 0, 0, 0, 0, 0], [0, 1, 1, 0, 0, 0, 0, 0], [0, 1, 1, 1, 1, 0, 0, 0], [1, 0, 0, 1, 1, 1, 1, 1]]
TRI = list(range(15, -1, -1)) + list(range(16))
NOISE = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068]
QF = [7457, 14913, 22371, 29829]                 # 4-step frame counter: quarter frames (cycles)


class Pulse:
    def __init__(s, n):
        s.n = n; s.duty = 0; s.halt = False; s.const = False; s.vol = 0; s.per = 0; s.len = 0
        s.env_start = False; s.env_div = 0; s.decay = 0; s.sw_en = False; s.sw_p = 0; s.sw_neg = False
        s.sw_sh = 0; s.sw_div = 0; s.sw_rel = False; s.phase = 0.0; s.en = False

    def write(s, r, v):
        if r == 0: s.duty = v >> 6; s.halt = bool(v & 0x20); s.const = bool(v & 0x10); s.vol = v & 15
        elif r == 1: s.sw_en = bool(v & 0x80); s.sw_p = (v >> 4) & 7; s.sw_neg = bool(v & 8); s.sw_sh = v & 7; s.sw_rel = True
        elif r == 2: s.per = (s.per & 0x700) | v
        else:
            s.per = (s.per & 0xFF) | (v & 7) << 8
            if s.en: s.len = LEN[v >> 3]
            s.env_start = True; s.phase = 0.0          # the sequencer restarts

    def target(s):
        c = s.per >> s.sw_sh
        if s.sw_neg: c = -c - (1 if s.n == 0 else 0)
        return s.per + c

    def quarter(s):
        if s.env_start: s.env_start = False; s.decay = 15; s.env_div = s.vol
        elif s.env_div == 0:
            s.env_div = s.vol
            if s.decay: s.decay -= 1
            elif s.halt: s.decay = 15
        else: s.env_div -= 1

    def half(s):
        if s.len and not s.halt: s.len -= 1
        if s.sw_div == 0 and s.sw_en and s.sw_sh and s.per >= 8 and s.target() <= 0x7FF: s.per = s.target()
        if s.sw_div == 0 or s.sw_rel: s.sw_div = s.sw_p; s.sw_rel = False
        else: s.sw_div -= 1

    def level(s):
        if not s.len or s.per < 8 or s.target() > 0x7FF: return 0
        return s.vol if s.const else s.decay

    def render(s, n):
        lv = s.level(); out = np.zeros(n)
        if lv == 0:
            return out
        f = CPU / (16 * (s.per + 1)); step = 8 * f / SR
        ph = s.phase + step * np.arange(n)
        seq = np.array(DUTY[s.duty])
        out = seq[(ph.astype(np.int64)) & 7] * lv
        s.phase = (s.phase + step * n) % 8
        return out


class Triangle:
    def __init__(s):
        s.ctrl = False; s.lin_load = 0; s.lin = 0; s.reload = False; s.per = 0; s.len = 0; s.phase = 0.0; s.en = False

    def write(s, r, v):
        if r == 0: s.ctrl = bool(v & 0x80); s.lin_load = v & 0x7F
        elif r == 2: s.per = (s.per & 0x700) | v
        elif r == 3:
            s.per = (s.per & 0xFF) | (v & 7) << 8
            if s.en: s.len = LEN[v >> 3]
            s.reload = True

    def quarter(s):
        if s.reload: s.lin = s.lin_load
        elif s.lin: s.lin -= 1
        if not s.ctrl: s.reload = False

    def half(s):
        if s.len and not s.ctrl: s.len -= 1

    def render(s, n):
        if not (s.len and s.lin) or s.per < 2:          # stopped: holds its last step
            return np.full(n, TRI[int(s.phase) & 31], dtype=float)
        f = CPU / (32 * (s.per + 1)); step = 32 * f / SR
        ph = s.phase + step * np.arange(n)
        out = np.array(TRI, dtype=float)[ph.astype(np.int64) & 31]
        s.phase = (s.phase + step * n) % 32
        return out


class Noise:
    def __init__(s):
        s.halt = False; s.const = False; s.vol = 0; s.mode = 0; s.per = 4; s.len = 0
        s.env_start = False; s.env_div = 0; s.decay = 0; s.lfsr = 1; s.acc = 0.0; s.en = False

    def write(s, r, v):
        if r == 0: s.halt = bool(v & 0x20); s.const = bool(v & 0x10); s.vol = v & 15
        elif r == 2: s.mode = v >> 7; s.per = NOISE[v & 15]
        elif r == 3:
            if s.en: s.len = LEN[v >> 3]
            s.env_start = True

    quarter = Pulse.quarter

    def half(s):
        if s.len and not s.halt: s.len -= 1

    def render(s, n):
        lv = (s.vol if s.const else s.decay) if s.len else 0
        out = np.zeros(n)
        clocks = CPU / s.per / SR                       # LFSR clocks per sample
        for i in range(n):
            s.acc += clocks
            while s.acc >= 1:
                s.acc -= 1
                b = (s.lfsr ^ (s.lfsr >> (6 if s.mode else 1))) & 1
                s.lfsr = (s.lfsr >> 1) | (b << 14)
            out[i] = 0 if (s.lfsr & 1) else lv
        return out


class APU:
    def __init__(s, mask=15):
        s.p = [Pulse(0), Pulse(1)]; s.t = Triangle(); s.n = Noise(); s.mask = mask; s.cyc = 0.0; s.qf = 0

    def write(s, a, v):
        r = a - 0x4000
        if r < 4: s.p[0].write(r, v)
        elif r < 8: s.p[1].write(r - 4, v)
        elif r < 12: s.t.write(r - 8, v)
        elif 12 <= r < 16: s.n.write(r - 12, v)
        elif r == 0x15:
            for k, c in enumerate((s.p[0], s.p[1], s.t, s.n)):
                c.en = bool(v >> k & 1)
                if not c.en: c.len = 0

    def frame(s):
        """one NES frame of samples (the writes of the frame already applied)"""
        out = []
        start = s.cyc
        for q in range(4):                              # up to each quarter-frame clock
            end = QF[q] if q < 3 else FRAME_CYC
            n = int(round((start + end) * SR / CPU)) - int(round((start + (QF[q - 1] if q else 0)) * SR / CPU))
            out.append(s.mix(max(n, 0)))
            for c in (s.p[0], s.p[1], s.t, s.n): c.quarter()
            if q in (1, 3):
                for c in (s.p[0], s.p[1], s.t, s.n): c.half()
        s.cyc += FRAME_CYC
        return np.concatenate(out)

    def mix(s, n):
        m = s.mask
        p1 = s.p[0].render(n) if m & 1 else np.zeros(n)
        p2 = s.p[1].render(n) if m & 2 else np.zeros(n)
        tr = s.t.render(n) if m & 4 else np.zeros(n)
        nz = s.n.render(n) if m & 8 else np.zeros(n)
        ps = p1 + p2
        pul = np.where(ps > 0, 95.88 / (8128.0 / np.maximum(ps, 1e-9) + 100), 0.0)
        x = tr / 8227 + nz / 12241
        tnd = np.where(x > 0, 159.79 / (1 / np.maximum(x, 1e-12) + 100), 0.0)
        return pul + tnd


def save_wav(path, x, sr=SR):
    x = x - np.mean(x)
    pk = np.max(np.abs(x)) or 1
    y = np.int16(np.clip(x / pk * 30000, -32767, 32767))
    w = wave.open(path, 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
    w.writeframes(y.tobytes()); w.close()


def nes_writes(nes_path, track, frames):
    sys.path.insert(0, os.path.join(ROOT, 'tools', 'gb'))
    from cynes import NES
    import fieldseq, battleseq
    nes = NES(nes_path)
    fr = fieldseq.frames_for('_%d' % (frames + 300)); f = 0
    per = []
    while f < len(fr) and len(per) < frames:
        if f == 3700:
            st = nes.save(); battleseq.poke_state(st, 0x4B, 0x40 | track); nes.load(st)
            nes.watch = (0x4000, 0x4017); per = []
        nes.controller = fr[f]; nes.step(1); f += 1
        if f > 3700: per.append([(a, v) for i, a, v in nes.watch])
        else: nes.watch
    return per


def main():
    a = sys.argv[1:]
    if a[0] == 'nes':
        rom, track, frames, out = a[1], int(a[2], 0), int(a[3]), a[4]
        mask = int(a[5], 0) if len(a) > 5 else 15
        apu = APU(mask)
        sig = []
        for ws in nes_writes(rom, track, frames):
            for ad, v in ws: apu.write(ad, v)
            sig.append(apu.frame())
        save_wav(out, np.concatenate(sig))
    else:
        rom, state, model, track, frames, out = a[1], a[2], a[3], int(a[4], 0), int(a[5]), a[6]
        nr51 = 'p FF25 %s\n' % a[7] if len(a) > 7 else ''     # (channels: NR51, after the state)
        cmds = 'L %s\n%sp DE4B %02X\nw %s\n' % (state, nr51, 0x40 | track, out) + 'f %d -\n' % frames + 'W\nq\n'
        subprocess.run([os.path.join(ROOT, 'build', 'sbsh'), rom, '--model', model], input=cmds,
                       text=True, capture_output=True, cwd=ROOT)


if __name__ == '__main__':
    main()
