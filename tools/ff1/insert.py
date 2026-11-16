"""Insert the English FF1 script into the MMC5 FF1 ROM (from tools/split/build_mmc5.py).

usage: insert.py ff1_mmc5.nes OUT.nes [--report FILE]

Done so far: Latin font, dialogue (table at 0x28000 in the original).
- Dialogue lines are set one tile row apart instead of two (English has no dakuten row),
  starting one row higher, so the original window (25 columns of text) holds 9 lines.
  Text is reflowed to that width; every string is checked to fit.
- Dialogue moves to the free MMC5 banks 16 (ids 0-127) and 17 (ids 128-255); each bank
  also holds the English item-name table at $B700 used by the {02} insert.
"""
import sys, os, json
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from latin_font import tile

HDR = 16; BANK = 0x4000
W, H = 25, 9                      # dialogue window text area (columns, lines)

ENC = {chr(0x30 + i): 0x80 + i for i in range(10)}           # digit tiles (redrawn to the new baseline)
for i in range(26):
    ENC[chr(65 + i)] = 0x8A + i; ENC[chr(97 + i)] = 0xA4 + i
ENC.update({'.': 0xBE, ',': 0xBF, "'": 0xC0, '"': 0xC1, '-': 0xC2, '…': 0xC3, '!': 0xC4, '?': 0xC5,
            ':': 0xCA, ';': 0xCB, '(': 0xCC, ')': 0xCD, '%': 0xCE, '&': 0xCF, '+': 0xD0,
            '[': 0xD1, ']': 0xD2, '/': 0x7A, ' ': 0xFF})
NEW_GLYPHS = [c for c in ENC if c not in ' /']

def font(rom):
    for ch in NEW_GLYPHS:
        o = HDR + 0x24000 + ENC[ch] * 16
        rom[o:o + 16] = tile(ch, fg=3, bg=2)

ITEM_MAX = 18                     # longest English item name ({02} insert), set in main

def vlen(s):                      # displayed width: {02} counts as the longest item name
    return len(s.replace('{02}', '#' * ITEM_MAX))

def wrap(text, width=W):
    """Reflow: the Japanese line breaks in FF1 windows are layout breaks."""
    lines = []; line = ''
    for w in text.replace('\n', ' ').split(' '):
        if not w: continue
        if not line: line = w
        elif vlen(line) + 1 + vlen(w) <= width: line += ' ' + w
        else: lines.append(line); line = w
    lines.append(line)
    return lines

def enc(s):
    out = bytearray(); i = 0
    while i < len(s):
        if s[i] == '{':
            j = s.index('}', i); out.append(int(s[i+1:j], 16)); i = j + 1
        elif s[i] == '\n': out.append(0x01); i += 1
        else: out.append(ENC[s[i]]); i += 1
    return bytes(out)

class Bank:
    def __init__(self, rom, n):
        self.rom, self.base = rom, HDR + n * BANK
        rom[self.base:self.base + BANK] = b'\xFF' * BANK
        self.free = [(0x8200, 0xB700), (0xB900, 0xC000)]
    def put_ptr(self, cpu, val):
        o = self.base + cpu - 0x8000; self.rom[o] = val & 0xFF; self.rom[o + 1] = val >> 8
    def alloc(self, data):
        for k, (a, b) in enumerate(self.free):
            if b - a >= len(data):
                o = self.base + a - 0x8000; self.rom[o:o + len(data)] = data
                self.free[k] = (a + len(data), b); return a
        raise SystemExit('bank full')

def put(rom, cpu, data):                  # fixed bank lives in banks 15 and 31
    for bank in (15, 31):
        o = HDR + bank * BANK + cpu - 0xC000
        rom[o:o + len(data)] = data

def insert_dialogue(rom, report):
    dia = json.load(open('script/ff1/dialogue.json'))
    items = json.load(open('script/ff1/items.json'))
    global ITEM_MAX; ITEM_MAX = max(len(e['en']) for e in items)
    bad = 0
    for half, bank_no in ((0, 16), (1, 17)):
        bank = Bank(rom, bank_no)
        for e in items:                   # {02} item-name table at $B700 (same layout as original)
            bank.put_ptr(0xB700 + 2 * e['id'], bank.alloc(enc(e['en'] or ' ') + b'\0'))
        for e in dia[half * 128:(half + 1) * 128]:
            lines = wrap(e['en'])
            if len(lines) > H or max(vlen(l) for l in lines) > W:
                bad += 1; report.append('DOES NOT FIT dialogue %d (%d lines)' % (e['id'], len(lines)))
            bank.put_ptr(0x8000 + 2 * e['id'], bank.alloc(enc('\n'.join(lines)) + b'\0'))
        report.append('bank %d free: %s' % (bank_no, [b - a for a, b in bank.free]))
    # $DB58: pick bank 16/17 from the id (trampoline in the free bytes at $F41E)
    put(rom, 0xDB58, bytes([0x4C, 0x1E, 0xF4]))
    put(rom, 0xF41E, bytes([0xAA, 0x0A, 0xA9, 0x10, 0x69, 0x00,   # TAX / ASL / LDA #16 / ADC #0
                            0x85, 0x57, 0x20, 0x03, 0xFE,         # STA $57 / JSR $FE03 (switch)
                            0x4C, 0x60, 0xDB]))                   # JMP $DB60
    put(rom, 0xDC81, bytes([0x69, 0x01]))     # newline: 1 tile row (was 2)
    put(rom, 0xD52E, bytes([0x69, 0x03]))     # first line one row higher (was row 4)
    return bad

if __name__ == '__main__':
    rom = bytearray(open(sys.argv[1], 'rb').read())
    report = []
    font(rom)
    bad = insert_dialogue(rom, report)
    open(sys.argv[2], 'wb').write(rom)
    print('\n'.join(report)); print('strings not fitting:', bad)
