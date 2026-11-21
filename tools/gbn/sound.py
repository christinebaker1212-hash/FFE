"""FF1 native build: music. FF1's music engine (bank 13 MusicPlay) is run as our own SM83 code
(the native port written for the recompiled build, tools/gb/rt/mus.s, from the disassembly's
description), its song data read from a copy of the user's bank 13; its output goes straight
to the Game Boy channels (src/snd.s): FF1's square / triangle periods become GB frequencies
through a table made here. The table addresses the engine needs are the ROM's own operands,
used only when the engine's bytes hash as expected (as in the recompiled build)."""
import hashlib, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))

SND_BANK, MUS_DATA = 7, 95
MUS_SHA1 = 'bd9d5ae99e4ca63c248c984e9c1b42df1844589f'   # (a hash of the code, not the code)


def mus_defs(rom):
    prg = rom.prg
    b13 = 13 * 0x4000 - 0x8000
    eng = prg[b13 + 0xB000:b13 + 0xB2F3]
    assert hashlib.sha1(eng).hexdigest() == MUS_SHA1, 'music engine: code not as expected'
    w = lambda a: prg[b13 + a] | prg[b13 + a + 1] << 8
    mus = dict(MUS_SCORE_HI=prg[b13 + 0xB043], MUS_P2C=w(0xB049), MUS_ENVSPD=w(0xB1FD),
               MUS_LENS=prg[b13 + 0xB2C3] | prg[b13 + 0xB2C7] << 8, MUS_OCT=w(0xB2D4),
               MUS_FREQS=prg[b13 + 0xB2D1] | prg[b13 + 0xB2D9] << 8,
               MUS_ENVPAT=prg[b13 + 0xB2E9] | prg[b13 + 0xB2ED] << 8)
    fix = prg[15 * 0x4000:16 * 0x4000]
    out = ''.join('%s = $%04X\n' % kv for kv in mus.items())
    return out


def engine_source():
    """tools/gb/rt/mus.s without its APU-layer output (snd.s supplies awf / aw, mrd)"""
    s = open(os.path.join(HERE, '..', 'gb', 'rt', 'mus.s')).read()
    i = s.index('; L = APU register (not a restart')
    j = s.index('; b13:B189 Music_ChannelScore')
    return s[:i] + s[j:]


def tables(rom):
    """bank SND_BANK $7000: NES period (11 bits) -> GB frequency (2048 x 2 bytes; the same
    formula for the pulses and, with a 32-step wave, the triangle); FF1's music per tileset
    (8) and per vehicle (9) at $6F00 / $6F10, found by their lookups in the fixed bank"""
    t = bytearray()
    for p in range(2048):
        x = 2048 - round(131072 * 16 * (p + 1) / 1789773)
        x = max(0, min(2047, x))
        t += x.to_bytes(2, 'little')
    fix = rom.prg[15 * 0x4000:16 * 0x4000]
    mt = {}
    for i in range(5, len(fix) - 2):
        if fix[i] == 0x85 and fix[i + 1] == 0x4B and fix[i - 3] == 0xBD and fix[i - 5] == 0xA6:
            a = fix[i - 2] | fix[i - 1] << 8
            mt[fix[i - 4]] = fix[a - 0xC000:a - 0xC000 + 9]
    veh = next(v for v in mt.values() if v[1] == v[2] and v[4] != v[1])
    ts = next(v for v in mt.values() if v is not veh)
    return bytes(t), bytes(ts[:8]), bytes(veh)
