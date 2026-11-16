"""FF1 (Famicom, FF I・II cart) character encoding. Font at 0x24000; dakuten
base table at 0x3DD47 / mark table at 0x3DD79 (codes 0x48-0x79)."""
HIRA = 'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわん'
SINGLE = {}
for i in range(10): SINGLE[0x80+i] = str(i)
for i, c in enumerate(HIRA): SINGLE[0x8A+i] = c
for i, c in enumerate('ァィゥェォッャュョ'): SINGLE[0xB7+i] = c
for i, c in enumerate('、。ー‥!?LEHPアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン'):
    SINGLE[0xC0+i] = c
for i, c in enumerate('/をっゃゅょ'): SINGLE[0x7A+i] = c
SINGLE[0xFF] = '　'
SINGLE[0xB9] = '。'  # FF1 replaces small ゥ with the full stop
SINGLE[0xC0] = '゛'; SINGLE[0xC1] = '゜'  # mark tiles
DAK = 'がぎぐげござじずぜぞだぢづでどばびぶべぼガギグゲゴザジズゼゾダヂヅデドバビブベボぱぴぷぺぽパピプペポ'
for i, c in enumerate(DAK): SINGLE[0x48+i] = c

def decode(data, off, maxlen=4000, ctrl=None):
    out = []; i = off
    while i - off < maxlen:
        b = data[i]; i += 1
        if b == 0x00: break
        if b == 0x01: out.append('\n'); continue
        if b < 0x48 or b not in SINGLE:
            out.append('{%02X}' % b); continue
        out.append(SINGLE[b])
    return ''.join(out), i - off
