"""FF3 (Famicom) character encoding, derived from the font at 0x1B000 and the
dakuten tables at 0x7F4E1 (base tile) / 0x7F515 (mark tile)."""
HIRA = 'あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわん'
SINGLE = {}
for i in range(10): SINGLE[0x80+i] = str(i)
for i, c in enumerate(HIRA): SINGLE[0x8A+i] = c
for i, c in enumerate('ァィゥェォッャュョ'): SINGLE[0xB7+i] = c
for i, c in enumerate('、。ー‥!?%/:『アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフ「ホマミムメモヤユヨラリルレロワン'):
    SINGLE[0xC0+i] = c
for i, c in enumerate('をっゃゅょ'): SINGLE[0x7B+i] = c
SINGLE[0xFF] = '　'
# 0x29-0x5B: base kana + dakuten/handakuten
DAK = 'がぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽヴガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポ'
for i, c in enumerate(DAK): SINGLE[0x29+i] = c

def decode(data, off, maxlen=4000):
    """Decode a 0-terminated string. Returns (text, length_in_bytes)."""
    out = []; i = off
    while i - off < maxlen:
        b = data[i]; i += 1
        if b == 0x00: break
        if b == 0x01: out.append('\n'); continue
        if b < 0x10: out.append('{%02X}' % b); continue
        if b < 0x28: out.append('{%02X:%02X}' % (b, data[i])); i += 1; continue
        out.append(SINGLE.get(b, '[%02X]' % b))
    return ''.join(out), i - off
