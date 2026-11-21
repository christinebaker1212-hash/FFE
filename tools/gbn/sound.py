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


# sound effects: FF1's menu ones (bank 14 PlaySFX_MenuMove / _MenuSel, bank 15 PlaySFX_Error:
# their register values are the code's immediates) and its three battle ones (bank 12
# data_BattleSoundEffects, found through PlayBattleSFX's table operand), in one format
# (FF1's battle one): header total frames, square blocks, noise blocks, 0; blocks of 8 bytes
# (square $4004-$4007 + frames, noise $400C, $400E + frames)
SFX_IDS = ('move', 'sel', 'error', 'magic', 'enemyhit', 'hit')
SFX_ADDR = 0x6D00


def sfx_data(rom):
    import math, re
    prg = rom.prg
    b12, b14, b15 = (prg[n * 0x4000:(n + 1) * 0x4000] for n in (12, 14, 15))
    one = lambda p, b: [m for m in re.finditer(p, b, re.S)]
    m = one(rb'\xA9(.)\x8D\x04\x40\xA9(.)\x8D\x05\x40\xA9(.)\x8D\x06\x40\xA9(.)\x8D\x07\x40'
            rb'\xA9(.)\x85\x7E', b14)
    assert len(m) == 1, 'menu select sound not found'
    v = m[0].groups()
    sel = bytes([v[4][0], 1, 0, 0]) + b''.join(v[:4]) + bytes([v[4][0], 0, 0, 0])
    m = one(rb'\xA9(.)\x8D\x04\x40\xA9(.)\x8D\x05\x40\xA9(.)\x8D\x06\x40\x4A\x8D\x07\x40\x85'
            rb'\x7E', b14)
    assert len(m) == 1, 'menu move sound not found'
    v = m[0].groups()
    n = v[2][0] >> 1
    mov = bytes([n, 1, 0, 0]) + b''.join(v[:3]) + bytes([n, n, 0, 0, 0])
    m = one(rb'\xA9(.)\x8D\x04\x40\xA9(.)\x8D\x05\x40\xA9(.)\x8D\x06\x40\xA9(.)\x8D\x07\x40'
            rb'\x60', b15)
    assert len(m) == 1, 'error sound not found'
    v = m[0].groups()
    err = bytes([17, 16, 0, 0]) + (b''.join(v) + bytes([1, 0, 0, 0])) * 16
    m = one(rb'\x48\x20..\x68\x0A\xAA\xBD(..)', b12)
    assert len(m) == 1, 'battle sounds not found'
    t = int.from_bytes(m[0].group(1), 'little') - 0x8000
    bt = []
    for k in range(3):
        a = int.from_bytes(b12[t + 2 * k:t + 2 * k + 2], 'little') - 0x8000
        h = b12[a:a + 3]
        bt.append(bytes(h) + b'\0' + b12[a + 3:a + 3 + 8 * max(h[1], h[2])])
    effects = [mov, sel, err] + bt
    base = SFX_ADDR + 2 * len(effects)
    ptrs, body = bytearray(), bytearray()
    for e in effects:
        ptrs += (base + len(body)).to_bytes(2, 'little')
        body += e
    # NES noise periods -> GB NR43 (as the recompiled build)
    periods = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068]
    nz = []
    for p in periods:
        f = 1789773 / p
        best = None
        for sh in range(14):
            for r in range(8):
                g = 262144 / ((r or 0.5) * (1 << sh))
                e = abs(math.log(g / f))
                if best is None or e < best[0]:
                    best = (e, sh << 4 | r)
        nz.append(best[1])
    return bytes(ptrs + body), bytes(nz)


def sfx_defs():
    return ''.join('SFX_%s = %d\n' % (n.upper(), i + 1) for i, n in enumerate(SFX_IDS))
