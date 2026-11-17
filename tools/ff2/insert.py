"""Insert the English script into the FF2 MMC5 ROM (build_mmc5.py output).

usage: insert.py ff2_mmc5.nes OUT.nes

ROM layout (16KB banks): 0-14 the game's banks, 15 the original fixed bank (free: the
patched copy in 31 is the one mapped at $C000), 16-30 free. Text placement:
  bank 10        names (table $8200/$8300, as the Japanese), rewritten in the space the
                 dialogue left; system strings (table $8400) for now in place
  banks 16/17    dialogue_b (map < $60) ids 0-127 / 128-255, table $8000
  banks 18/19    dialogue_a ids 0-127 / 128-255, table $8000
  bank 20        events, table $8000
  bank 22        image of the ExRAM code (copied to $5C00 at reset)
Text in banks 16-20 is drawn one tile row per line (the Japanese spends a row on
dakuten); see EXRAM_SRC."""
import sys, os, json, re
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from latin_font import tile
from asm6502 import asm

HDR = 16; BANK = 0x4000
FONT = 0x24320                          # tile N = code N (PRG offset)
DLG_W = 26                              # dialogue window: 26 columns, 8 rows
ONE_ROW = (16, 21)                      # banks drawn one row per line
DB_BANK, DA_BANK, EV_BANK, CODE_BANK = 16, 18, 20, 22

ENC = {chr(0x30 + i): 0x80 + i for i in range(10)}
for i in range(26):
    ENC[chr(65 + i)] = 0x8A + i; ENC[chr(97 + i)] = 0xA4 + i
ENC.update({'.': 0xBE, ',': 0xBF, "'": 0xC0, '"': 0xC1, '-': 0xC2, '…': 0xC3, '!': 0xC4, '?': 0xC5,
            '%': 0xC6, ':': 0xCA, ';': 0xCB, '(': 0xCC, ')': 0xCD, '+': 0xCE, '&': 0xCF,
            '[': 0x78, ']': 0x79, '/': 0x7A, ' ': 0xFF})
NEW_GLYPHS = [c for c in ENC if c not in ' []/']
SPECIAL = {0xC7: 'M', 0xC8: 'H', 0xC9: 'P'}     # 'HP' / 'MP' labels drawn by the game

def font(rom):
    for ch in NEW_GLYPHS:
        o = HDR + FONT + ENC[ch] * 16; rom[o:o + 16] = tile(ch, fg=3, bg=2)
    for code, ch in SPECIAL.items():
        o = HDR + FONT + code * 16; rom[o:o + 16] = tile(ch, fg=3, bg=2)

TOKEN = re.compile(r'\{([0-9A-F]{2})(?::([0-9A-F]{2}))?\}|\[([0-9A-F]{2})\]')

def enc(s):
    out = bytearray(); i = 0
    while i < len(s):
        m = TOKEN.match(s, i)
        if m:
            if m.group(3): out.append(int(m.group(3), 16))
            else:
                out.append(int(m.group(1), 16))
                if m.group(2): out.append(int(m.group(2), 16))
            i = m.end(); continue
        if s[i] == '\n': out.append(0x01)
        else: out.append(ENC[s[i]])
        i += 1
    return bytes(out)

NAMES = {}
def vlen(s):
    """Displayed width: names inserted by codes count at their English length."""
    n = 0; i = 0
    while i < len(s):
        m = TOKEN.match(s, i)
        if m:
            c = m.group(1)
            if m.group(3): n += 1
            elif c == '18': n += vlen(NAMES[int(m.group(2), 16)])
            elif c in ('07', '10', '11', '12', '13'): n += 6
            i = m.end(); continue
        n += 1; i += 1
    return n

SPEAKER = re.compile(r'^(\{1[0-3]:..\}|\{18:..\}|\{07\}|[A-Z][\w\'-]*(?: [A-Z][\w\'-]*)?): "')

def paragraphs(text):
    """Japanese line breaks are layout, except blank lines, speaker turns and indented
    lines, which start a new paragraph."""
    paras = []
    for line in text.split('\n'):
        if paras and line and paras[-1] and not SPEAKER.match(line) and not line.startswith(' ') \
                and not paras[-1].startswith(' '):
            paras[-1] += ' ' + line
        else: paras.append(line)
    return paras

def flow(para, width):
    lead = len(para) - len(para.lstrip(' '))
    words = para.strip(' ').split(' ')
    lines = []; line = ' ' * lead
    for w in words:
        if not w: continue
        if not line.strip(): line += w
        elif vlen(line) + 1 + vlen(w) <= width: line += ' ' + w
        else: lines.append(line); line = w
    lines.append(line)
    return lines

def fix_keyword_columns(line):
    """{16:xx} sets the drawing column (and records the keyword position): xx is the
    column where the keyword starts in this line."""
    out = ''; i = 0
    while i < len(line):
        m = TOKEN.match(line, i)
        if m and m.group(1) == '16':
            out += '{16:%02X}' % vlen(out); i = m.end(); continue
        if m: out += m.group(0); i = m.end(); continue
        out += line[i]; i += 1
    return out

def layout(text, width=DLG_W):
    lines = []
    for p in paragraphs(text):
        lines += flow(p, width) if p.strip() else ['']
    lines = [fix_keyword_columns(l) for l in lines]
    for l in lines: assert vlen(l) <= width, (l, vlen(l))
    return '\n'.join(lines)

class Bank:
    def __init__(self, rom, n, free):
        self.rom, self.base, self.free = rom, HDR + n * BANK, list(free)
    def put_ptr(self, cpu, val):
        o = self.base + cpu - 0x8000; self.rom[o] = val & 0xFF; self.rom[o + 1] = val >> 8
    def alloc(self, data):
        for k, (a, b) in enumerate(self.free):
            if b - a >= len(data):
                o = self.base + a - 0x8000; self.rom[o:o + len(data)] = data
                self.free[k] = (a + len(data), b); return a
        raise SystemExit('bank full')

def bank_put(rom, bank, cpu, data):
    o = HDR + bank * BANK + cpu - (0xC000 if bank == 31 else 0x8000)
    rom[o:o + len(data)] = data

def bank_get(rom, bank, cpu, n=1):
    o = HDR + bank * BANK + cpu - (0xC000 if bank == 31 else 0x8000)
    return bytes(rom[o:o + n])

SPLIT = {}
def put_table(rom, name, banks, table, report):
    rows = json.load(open('script/ff2/%s.json' % name))
    size = {e['id']: len(enc(layout(e['en']))) + 1 for e in rows if e['en']}
    total = sum(size.values()); acc = 0; split = 256
    if len(banks) > 1:                       # first id of the second bank: halves balanced
        for i in sorted(size):
            acc += size[i]
            if acc > total / 2: split = i; break
    SPLIT[name] = split
    used = {}
    for k, b in enumerate(banks):
        rom[HDR + b * BANK:HDR + (b + 1) * BANK] = b'\xFF' * BANK
        used[b] = Bank(rom, b, [(table + 0x200, 0xC000)])
    for e in rows:
        b = banks[1 if e['id'] >= split else 0]
        txt = layout(e['en']) if e['en'] else ''
        used[b].put_ptr(table + 2 * e['id'], used[b].alloc(enc(txt) + b'\0'))
    for b in banks:
        report.append('%s bank %d free: %d' % (name, b, sum(y - x for x, y in used[b].free)))

def insert_names(rom, report):
    """Names (items, spells, key words; {18:xx}) stay in bank 10 at tables $8200/$8300,
    strings in the space the dialogue (now banks 18/19) used."""
    bank = Bank(rom, 10, [(0x8600, 0xA920 + 0x0720)])     # dialogue_a + old names area
    for e in json.load(open('script/ff2/names.json')):
        bank.put_ptr(0x8200 + 2 * e['id'], bank.alloc(enc(e['en'] or ' ') + b'\0'))
    report.append('names bank 10 free: %d' % sum(y - x for x, y in bank.free))

EXRAM_SRC = '''
    org $5C00
TMP:    .ds 1
ONE:    .ds 1
    .ds 14
dlgbank:        ; bank 14 $962F: dialogue bank from the map ($A0) and the id ($92)
    lda $A0
    cmp #$60
    bcs .a
    ldx #DB
    lda $92
    cmp #SB
    bcc .c
    inx
    bcs .c
.a:
    ldx #DA
    lda $92
    cmp #SA
    bcc .c
    inx
.c:
    stx $93
    rts
txton:          ; $EAAC (text drawing starts; window frames are drawn elsewhere with the
    lda $93     ;   same flush): one row per line while drawing text from banks R0..R1-1
    jsr $FE03
    lda $93
    cmp #R0
    bcc .n
    cmp #R1
    bcs .n
    lda #1
    sta ONE
    rts
.n:
    lda #0
    sta ONE
    rts
txtend:         ; $EAD8 (end of the text): in one-row mode blank the window's rows below
    lda ONE     ;   it (the scroll redraws from a later line; rows past the end would keep
    beq txtoff  ;   their old line)
.c:
    lda $1F
    clc
    adc #1
    cmp $3D
    bcs txtoff
    inc $1F
    jsr $F053
    jmp .c
txtoff:         ; $EADF (window full)
    lda #0
    sta ONE
    lda $57
    jmp $FE03
onerow:         ; C = 1 in one-row mode
    lda ONE
    cmp #1
    rts
h_nl:           ; $EB2E newline: one row (or two, Japanese layout)
    inc $1F
    jsr onerow
    bcs .r
    inc $1F
.r:
    rts
h_sub:          ; $EA78/$EA82 (paged text): rows scrolled per line
    sta TMP
    jsr onerow
    lda TMP
    bcc .two
    sec
    sbc #1
    rts
.two:
    sec
    sbc #2
    rts
h_flush:        ; $F069 line flush: lower-row buffer only, on row $3B
    lda $38
    sta $3A
    jsr onerow
    bcs .one
    jmp $F06D
.one:
    jsr $EE1F
    ldx #0
.a:
    lda $07A0,x
    sta $2007
    inx
    cpx $91
    bcc .a
    cpx $3C
    bcs .d
    lda $3A
    and #$20
    eor #$20
    sta $3A
    jsr $EE1F
    ldx $91
.b:
    lda $07A0,x
    sta $2007
    inx
    cpx $3C
    bcc .b
.d:
    jmp $F0D0
'''

INIT_SRC = '''
    org $FF00       ; (free: the cart's game-select boot path, bypassed)
    lda #2
    sta $5104
    lda #$80+CODE2
    sta $5115
    ldx #0
.l:
    lda $8000,x
    sta $5C00,x
    lda $8100,x
    sta $5D00,x
    lda $8200,x
    sta $5E00,x
    lda $8300,x
    sta $5F00,x
    inx
    bne .l
    jmp $FE79
'''

def jsr(a): return bytes([0x20, a & 0xFF, a >> 8])
def jmp(a): return bytes([0x4C, a & 0xFF, a >> 8])

def engine(rom, report):
    ex = asm(EXRAM_SRC, syms={'DB': DB_BANK, 'DA': DA_BANK, 'SB': SPLIT['dialogue_b'], 'SA': SPLIT['dialogue_a'], 'R0': ONE_ROW[0], 'R1': ONE_ROW[1]})
    assert ex.org + len(ex.bytes) <= 0x6000
    rom[HDR + CODE_BANK * BANK:HDR + (CODE_BANK + 1) * BANK] = b'\xFF' * BANK
    rom[HDR + CODE_BANK * BANK:HDR + CODE_BANK * BANK + len(ex.bytes)] = ex.bytes
    report.append('ExRAM code: %d bytes' % len(ex.bytes))
    L = ex.labels
    init = asm(INIT_SRC, syms={'CODE2': CODE_BANK * 2})
    assert init.org + len(init.bytes) <= 0xFFB0
    bank_put(rom, 31, init.org, init.bytes)
    assert bank_get(rom, 31, 0xFE67, 3) == jmp(0xFE79)
    bank_put(rom, 31, 0xFE67, jmp(init.org))
    # dialogue: bank by map and id
    assert bank_get(rom, 14, 0x962F, 12) == bytes.fromhex('a5a0a206c9609002a20a8693')
    bank_put(rom, 14, 0x962F, jsr(L['dlgbank']) + b'\xEA' * 9)
    # events: bank 20, table $8000
    assert bank_get(rom, 31, 0xE8AE, 2) == b'\xa9\x0d' and bank_get(rom, 31, 0xE8B6, 2) == b'\xa9\xbf'
    bank_put(rom, 31, 0xE8AF, bytes([EV_BANK])); bank_put(rom, 31, 0xE8B7, b'\x80')
    # one row per line
    assert bank_get(rom, 31, 0xEB2E, 4) == b'\xe6\x1f\xe6\x1f'
    bank_put(rom, 31, 0xEB2E, jsr(L['h_nl']) + b'\xEA')
    for a in (0xEA78, 0xEA82):
        assert bank_get(rom, 31, a, 3) == b'\x38\xe9\x02'
        bank_put(rom, 31, a, jsr(L['h_sub']))
    assert bank_get(rom, 31, 0xEAAC, 5) == b'\xa5\x93\x20\x03\xfe'
    bank_put(rom, 31, 0xEAAC, jsr(L['txton']) + b'\xEA\xEA')
    for a, h in ((0xEAD8, 'txtend'), (0xEADF, 'txtoff')):
        assert bank_get(rom, 31, a, 5) == b'\xa5\x57\x20\x03\xfe'
        bank_put(rom, 31, a, jsr(L[h]) + b'\xEA\xEA')
    assert bank_get(rom, 31, 0xF069, 4) == b'\xa5\x38\x85\x3a'
    bank_put(rom, 31, 0xF069, jmp(L['h_flush']) + b'\xEA')

if __name__ == '__main__':
    rom = bytearray(open(sys.argv[1], 'rb').read())
    report = []
    for e in json.load(open('script/ff2/names.json')): NAMES[e['id']] = e['en']
    font(rom)
    insert_names(rom, report)
    put_table(rom, 'dialogue_b', [DB_BANK, DB_BANK + 1], 0x8000, report)
    put_table(rom, 'dialogue_a', [DA_BANK, DA_BANK + 1], 0x8000, report)
    put_table(rom, 'events', [EV_BANK], 0x8000, report)
    engine(rom, report)
    open(sys.argv[2], 'wb').write(rom)
    print('\n'.join(report))
