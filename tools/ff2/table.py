"""FF2 (Famicom, FF I・II cart) character encoding. Runtime font = tiles at
0x64320 (tile N = code N). Dakuten: codes 0x3C-0x6D, base table 0x7EEE2,
mark table 0x7EF15 (both indexed by code-0x3B)."""
HIRA = 'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわん'
SINGLE = {}
for i in range(10): SINGLE[0x80+i] = str(i)
for i, c in enumerate(HIRA): SINGLE[0x8A+i] = c
for i, c in enumerate('ァィ「ェォッャュョ'): SINGLE[0xB7+i] = c
for i, c in enumerate('、。ー‥!?%MHPアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン'):
    SINGLE[0xC0+i] = c
for i, c in enumerate('[]/をっゃゅょ'): SINGLE[0x78+i] = c
SINGLE[0xFF] = '　'
DAK = 'がぎぐげござじずぜぞだぢづでどばびぶべぼガギグゲゴザジズゼゾダヂヅデドバビブベボぱぴぷぺぽパピプペポ'
for i, c in enumerate(DAK): SINGLE[0x3C+i] = c

def decode(data, off, maxlen=4000):
    out = []; i = off
    while i - off < maxlen:
        b = data[i]; i += 1
        if b == 0x00: break
        if b == 0x01: out.append('\n'); continue
        if b < 0x10: out.append('{%02X}' % b); continue
        if b < 0x3B: out.append('{%02X:%02X}' % (b, data[i])); i += 1; continue
        out.append(SINGLE.get(b, '[%02X]' % b))
    return ''.join(out), i - off
