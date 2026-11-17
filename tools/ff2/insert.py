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
from latin_font import tile, proportional, right_label, left_label
from asm6502 import asm

HDR = 16; BANK = 0x4000
FONT = 0x24320                          # tile N = code N (PRG offset)
DLG_W = 26                              # dialogue window: 26 columns, 8 rows
ONE_ROW = (16, 21)                      # banks drawn one row per line
DB_BANK, DA_BANK, EV_BANK, CODE_BANK = 16, 18, 20, 22
BT_BANK = 21                            # battle text (bank 5's three tables)
BUF, SAVE = 0x5E40, 0x5E80              # ExRAM: battle text buffer (64), box save stack
CNTAB = 0xBE00                          # bank 21: enemy-list compact names, by monster

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
            elif c == '02': n += 20                       # item name (longest)
            elif c in ('03', '04', '05'): n += 6          # amounts of money
            elif c == '06': n += 1
            i = m.end(); continue
        n += 1; i += 1
    return n

SPEAKER = re.compile(r'^(\{1[0-3]:..\}|\{18:..\}|\{07\}|[A-Z][\w\'-]*(?: [A-Z][\w\'-]*)?): "')

def paragraphs(text):
    """Japanese line breaks are layout, except blank lines, speaker turns, lines opening
    a quotation and indented lines, which start a new paragraph."""
    paras = []
    for line in text.split('\n'):
        if paras and line and paras[-1] and not SPEAKER.match(line) and not line.startswith((' ', '"')) \
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

def balanced(line, width):
    """A line wrapped to the fewest rows, the rows as even as possible."""
    n = len(flow(line, width))
    if n == 1: return [line]
    w = line.split(' ')
    if n == 2:
        best = min(([' '.join(w[:k]), ' '.join(w[k:])] for k in range(1, len(w))),
                   key=lambda p: max(vlen(p[0]), vlen(p[1])))
        if max(vlen(x) for x in best) <= width: return best
    return flow(line, width)

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
    if name == 'events': EV_FREE[0] = used[banks[0]].free

def ending(rom, report):
    """Ending (bank 4 $BC00, drawn by bank 14 $BAAF in 24 columns from (4,4); the four
    pieces are read one after another): moved to the events bank (one row per line),
    each line wrapped to 24 and centred as the Japanese centres them."""
    data = b''
    for e in json.load(open('script/ff2/ending.json')):
        if not e['en'].strip():
            data += enc(e['en']) + b'\0'; continue
        lines = []
        for line in e['en'].split('\n'):
            for l in (balanced(line.strip(), 24) if line.strip() else ['']):
                lines.append(' ' * ((24 - vlen(l)) // 2) + l if l else '')
        data += enc('\n'.join(lines)) + b'\0'
    bank = Bank(rom, EV_BANK, EV_FREE[0])
    a = bank.alloc(data)
    assert bank_get(rom, 14, 0xBACD, 2) == b'\xa9\x04' and bank_get(rom, 14, 0xBAD5, 2) == b'\xa9\xbc'
    bank_put(rom, 14, 0xBACE, bytes([EV_BANK])); bank_put(rom, 14, 0xBAD2, bytes([a & 0xFF]))
    bank_put(rom, 14, 0xBAD6, bytes([a >> 8]))
    report.append('ending in bank %d at %04X' % (EV_BANK, a))

EV_FREE = [None]

WIDE_NAMES = {'Richard': 0xE0}     # 7 letters in the 6-letter name field: own tiles

def guest_names(rom):
    """Guest characters' names (6 bytes in their templates, bank 0 $9102 + $80 n). A name
    longer than 6 letters is drawn proportionally on 6 tiles of its own."""
    for e in json.load(open('script/ff2/guest_names.json')):
        n = e['en']
        if n in WIDE_NAMES:
            base = WIDE_NAMES[n]
            for t, data in enumerate(proportional(n, 6, fg=3, bg=2)):
                o = HDR + FONT + (base + t) * 16; rom[o:o + 16] = data
            data = bytes(range(base, base + 6))
        else:
            data = enc(n); assert len(data) <= 6, n
            data += b'\xFF' * (6 - len(data))
        o = HDR + int(e['off'], 16) - 0x40000
        rom[o:o + 6] = data

def insert_names(rom, report):
    """Names (items, spells, key words; {18:xx}) stay in bank 10 at tables $8200/$8300,
    strings in the space the dialogue (now banks 18/19) used."""
    bank = Bank(rom, 10, [(0x8600, 0xC000)])        # dialogue_a, names, system areas
    for e in json.load(open('script/ff2/names.json')):
        bank.put_ptr(0x8200 + 2 * e['id'], bank.alloc(enc(e['en'] or ' ') + b'\0'))
    return bank

SYS_W = {i: 26 for i in list(range(0, 12)) + list(range(13, 21)) + [22, 25, 63, 64, 68, 71, 72, 76, 77]}
SYS_W.update({i: 28 for i in range(42, 63)})
PROLOGUE = 73                       # window 24: 28 columns, 26 rows
ONE_ROW_LAYOUT = {27}               # menu layouts drawn one row per line
# inventory (32 slots and the bin): one column of full names, one row each ({08} at each
# line start: one-row mode also when the list is redrawn from a later line)
SYS_LAYOUT = {37: '\n'.join(['{08}{17:01}{1A:%02X}' % i for i in range(32)] + ['{08}{17:01}{0F}'])}
# equipment (window 12, made 14 rows inside): each slot's label, then its name in full;
# the cursor entries ({16}) keep the Japanese order (right hand, head, arms, left hand,
# body, item, item)
EQUIP_LABELS = ['Right Hand', 'Head', 'Arms', 'Left Hand', 'Body', 'Item']
# (the cursor is on the label: the hand reaches one row down, onto the indented name's
# empty columns)
SYS_LAYOUT[36] = '\n'.join(['{08}{16:02}' + EQUIP_LABELS[k] + '\n{08}{14:03}{10:%02X}' % c
                            for k, c in enumerate((6, 3, 5, 7, 4, 8))] + ['{08}{16:02}{10:09}'])
SYS_LAYOUT[35] = 'Attack  ..{10:24}\nDefense ..{10:25}'
# key-word lists (65: key words, 16; 66: items, 32; field window 2, made 21 inside):
# one column, one row per line
SYS_LAYOUT[65] = '\n'.join('{08}{17:01}{1B:%02X}' % i for i in range(16))
SYS_LAYOUT[66] = '\n'.join('{08}{17:01}{1A:%02X}' % i for i in range(32))
# airship destinations (message window): the question, then the four places with fares
SYS_LAYOUT[21] = '{08}Where are you headed?\n' + '\n'.join(
    '{16:02}%s{14:14}%d' % (p, 100 * (k + 1)) for k, p in enumerate(('Bafsk', 'Salamand', 'Semite Falls', 'Kashuon')))
# status (window 15, 27 x 24 inside): one column, one row per line (two columns of
# English labels and values do not fit 27)
STAT = [('Strength', 0x26, ''), ('Agility', 0x27, ''), ('Stamina', 0x28, ''), ('Intelligence', 0x29, ''),
        ('Spirit', 0x2A, ''), ('Magic Power', 0x2B, '')]
COMBAT = [('Attack', 0x24, ''), ('Hit Rate', 0x2D, '%'), ('Defense', 0x25, ''), ('Evasion', 0x2E, '%'),
          ('Magic Defense', 0x2F, '%')]
def stat_line(l, c, pct, w=3):    # numbers right-aligned (attributes print 2 wide)
    return ' %s{14:0F}..%s{10:%02X}%s' % (l, ' ' * (3 - w), c, pct)
SYS_LAYOUT[39] = '\n'.join(
    ['{08}{14:05}{10:02}{14:0E}HP {10:20}/{10:21}', '{14:0E}MP  {10:22}/ {10:23}', '', '']
    + [stat_line(*x, w=2) for x in STAT] + ['', ' {10:00}'] + [stat_line(*x) for x in COMBAT]
    + ['\u2026' * 27, ' Skill Level', ' [6E] {10:30}{14:0A}[71] {10:33}{14:13}[74] {10:36}',
       ' [6F] {10:31}{14:0A}[72] {10:34}{14:13}[75] {10:37}', ' [70] {10:32}{14:0A}[73] {10:35}'])
# magic (window 11, 18 rows inside): one column of the 16 spells with their levels, then
# the bin (two columns cannot hold an English name, its level and the hand's cells)
SYS_LAYOUT[38] = '\n'.join(['{08}{17:02}{10:%02X}{14:0B}{10:%02X}' % (0x0A + i, 0x38 + i)
                            for i in range(16)] + ['{08}{17:02}{0F}'])

# status words (ids 240-253): the battle status window gives them the maximum-HP slot,
# 4 cells in the Japanese (right-aligned kana); English takes the slot and the blank cell
# after it. Words up to 5 letters are right-aligned in the regular letters; longer ones are
# drawn on 5 tiles of their own, right-aligned (regular letters if they fit, else
# condensed ones).
STATUS_SLOT = 5
STATUS_DRAWN = {240: False, 242: 'thin', 244: True, 245: True, 250: False}
STATUS_TILES = list(range(0xD0, 0xE0)) + list(range(0xE6, 0xF0))     # unused katakana

def status_word(rom, i, word, tiles):
    if i not in STATUS_DRAWN:
        assert len(word) <= STATUS_SLOT, word
        return enc(' ' * (STATUS_SLOT - len(word)) + word)
    codes = [tiles.pop(0) for _ in range(STATUS_SLOT)]
    for c, data in zip(codes, right_label(word, STATUS_SLOT, STATUS_DRAWN[i], fg=3, bg=2)):
        o = HDR + FONT + c * 16; rom[o:o + 16] = data
    return bytes(codes)

def system_strings(rom, report, bank):
    """System strings (table bank 10 $8400) after the names. Messages (SYS_W) are drawn
    one row per line, reflowed to their window like the dialogue (the Japanese indents
    each line by a space); menu layouts
    keep the Japanese structure; the prologue is reflowed by paragraph and centred."""
    one = set(SYS_W) | {PROLOGUE} | ONE_ROW_LAYOUT
    tiles = list(STATUS_TILES)
    for e in json.load(open('script/ff2/system.json')):
        t = e['en']
        if 240 <= e['id'] <= 253 and t:
            bank.put_ptr(0x8400 + 2 * e['id'], bank.alloc(status_word(rom, e['id'], t, tiles) + b'\0'))
            continue
        if e['id'] in SYS_W:
            t = layout('\n'.join(l.strip() for l in t.split('\n')), SYS_W[e['id']])
        elif e['id'] in SYS_LAYOUT:
            t = SYS_LAYOUT[e['id']]
        elif e['id'] == PROLOGUE:
            lines = []
            for para in t.split('\n\n'):
                if lines: lines.append('')
                for l in flow(' '.join(para.split('\n')), 28):
                    lines.append(' ' * ((28 - vlen(l)) // 2) + l)
            assert len(lines) <= 26, len(lines)
            t = '\n'.join(lines)
        bank.put_ptr(0x8400 + 2 * e['id'], bank.alloc(enc(t) + b'\0'))
    bits = bytearray(32)
    for i in one: bits[i >> 3] |= 1 << (i & 7)
    report.append('names+system bank 10 free: %d' % sum(y - x for x, y in bank.free))
    return bytes(bits)

EXRAM_SRC = '''
    org $5C00
TMP:    .ds 1
ONE:    .ds 1
SLOT1:  .ds 1
BLEN:   .ds 1   ; battle text: length, split index, split cost
BSPL:   .ds 1
BCOST:  .ds 1
BOXF:   .ds 1   ; 1: next battle text is a box entry (enemy list)
CNEXT:  .ds 1   ; enemy list: next free tile slot, tiles of this name, data index
CN_N:   .ds 1
CN_P:   .ds 1
    .ds 6
SYSONE: .ds 32  ; one-row system strings (bit k of byte n: id 8n+k)
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
    lda $93     ; system strings (bank 10, table $8400): per-id bitmap
    cmp #10
    bne .r
    lda $95
    cmp #$84
    bne .r
    lda $92
    lsr a
    lsr a
    lsr a
    tax
    lda $92
    and #7
    tay
    lda SYSONE,x
.s:
    dey
    bmi .t
    lsr a
    jmp .s
.t:
    and #1
    sta ONE
.r:
    ldy #0      ; a line starting with code 08 is one-row (lists redrawn from any line)
    lda ($3E),y
    cmp #$08
    bne .x
    lda #1
    sta ONE
.x:
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
h_ypos:         ; $EC55: row of a recorded position ($98 + $1F assumes the dakuten row)
    lda $98
    clc
    adc $1F
    ldx ONE
    beq .r
    sec
    sbc #1
.r:
    rts
shoptpl:        ; bank 14 $90FD builds the buy list from this ($FF: next shop byte): one row
    .db $08     ;   per item, name from column 2, price at column 21 (the Japanese: 14
    .db $16,$02,$18,$FF,$14,$15,$19,$FF,$01     ; columns beside the prompt)
    .db $16,$02,$18,$FF,$14,$15,$19,$FF,$01
    .db $16,$02,$18,$FF,$14,$15,$19,$FF,$01
    .db $16,$02,$18,$FF,$14,$15,$19,$FF,$00
itemmenu:       ; bank 14 $AEC5 (from the main menu): the item list (system string 37) as
    jsr $905E   ;   one column of full names that scrolls in window 7 (as the equipment
.full:          ;   screen's list does); the slots come from the cursor entries
    jsr $B380
    lda #0
    sta $A2
    sta $A3
    sta $A4
    sta $7AF0
    ldx #6
    jsr $B486
    lda #$1F
    jsr $B3DF
    ldx #7
    jsr $B486
    lda #$25
    jsr $B3F0
    jsr $94EB
    lda #1
    sta $A4
.l1:
    jsr $B401
    lda #4
    jsr $972D
    lda $25
    bne .exit
    lda $24
    beq .l1
    jsr $905E
    jsr curslot
    sta SLOT1
    lda #1
    sta $A2
.l2:
    jsr repin
    jsr $B401
    lda #4
    jsr $972D
    lda $25
    beq .a2
    jsr $905E
    lda #0
    sta $A2
    beq .l1
.a2:
    lda $24
    beq .l2
    jsr $905E
    lda #0
    sta $A2
    jsr curslot
    sta $81
    lda SLOT1
    sta $80
    jsr $A871
    bcc .keep
    jsr $905E
    jmp .full
.keep:          ; redraw the list from its top visible line (the scroll stays)
    jsr $9523
    lda $1C
    sta $3E
    lda $1D
    sta $3F
    jsr $E7AC
    jmp .l1
.exit:
    jsr $905E
    lda #0
    sta $78F0
    sta $A4
    jmp $B380
curslot:        ; A = slot of the cursor entry ($20 = the bin)
    ldx $7AF0
    lda $7A02,x
    cmp #$0F
    bne .s
    lda #$20
    rts
.s:
    lda $7A03,x
    rts
repin:          ; first cursor on SLOT1's entry if it is in view, else hidden
    ldx #0
.f:
    cpx $7AF1
    bcs .no
    lda SLOT1
    cmp #$20
    bne .i
    lda $7A02,x
    cmp #$0F
    beq .y
    bne .n
.i:
    lda $7A02,x
    cmp #$1A
    bne .n
    lda $7A03,x
    cmp SLOT1
    beq .y
.n:
    inx
    inx
    inx
    inx
    bne .f
.y:
    lda $7A00,x
    sta $7800
    lda $7A01,x
    sta $7801
    lda #0
    sta $78F0
    lda #4
    sta $78F1
    lda #1
    sta $A2
    rts
.no:
    lda #0
    sta $A2
    rts
fdbank:         ; $FD8C (battle string fetch, table in bank X): bank 5's three battle text
    txa         ;   tables are read from the English bank BT
    cmp #5
    bne .k
    lda #BT
.k:
    jmp $FE1A
SLOTS:          ; tile codes free in battle (never loaded; unused kana) for compact names
    .db $4C, $4D, $4E, $4F, $EF, $F0, $F1, $F2, $F3, $F4, $F5, $F6, $7B, $7C, $7D, $7E, $7F
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
'''

FIXA_SRC = '''
    org $FF30       ; (fixed bank: unused bytes)
btidy:          ; battle text in BUF for a box $45 wide: no leading, trailing or double
    ldx #0      ;   spaces; BLEN its length; BSPL the space where it splits into the most
    ldy #0      ;   even two rows that fit ($FF: one row)
    lda #$FF
    sta TMP
.n:
    lda BUF,x
    beq .e
    inx
    cmp #$FF
    bne .c
    cmp TMP
    beq .n
.c:
    sta TMP
    sta BUF,y
    iny
    bne .n
.e:
    lda TMP
    cmp #$FF
    bne .t
    cpy #0
    beq .t
    dey
.t:
    lda #0
    sta BUF,y
    sty BLEN
    lda #$FF
    sta BCOST
    sta BSPL
    cpy $45
    beq .r
    bcc .r
    ldx #0
.s:
    lda BUF,x
    beq .r
    cmp #$FF
    bne .sn
    cpx $45
    beq .k1
    bcs .r
.k1:
    stx TMP
    lda BLEN
    clc
    sbc TMP
    cmp $45
    beq .k2
    bcs .sn
.k2:
    cmp TMP
    bcs .m
    lda TMP
.m:
    cmp BCOST
    bcs .sn
    sta BCOST
    stx BSPL
.sn:
    inx
    bne .s
.r:
    rts
'''

B12_SRC = '''
    org $95E7       ; bank 12: the Japanese converter (dakuten, handakuten), replaced
bconv:          ; battle text (BUF, 0-terminated) into the tile buffer at $A8/$A9 +
    clc         ;   $6F:$44, rows $45 wide. In a box ($44 = $45: the main row of a 2-row
    lda $A8     ;   interior whose upper row is the Japanese dakuten row) the text is
    adc $44     ;   tidied and, when wider than the box, split in two rows (btidy). Lists
    sta $6C     ;   ($44 <> $45) are copied as they are.
    lda $A9
    adc $6F
    sta $6D
    ldx #0
    lda BOXF
    stx BOXF
    bne .b
    lda $44
    cmp $45
    bne .w
.b:
    jsr btidy
    ldx BSPL
    inx
    beq .w
    sec
    lda $6C
    sbc $45
    sta $6A
    lda $6D
    sbc #0
    sta $6B
    ldy #0
.u:
    cpy BSPL
    beq .w
    lda BUF,y
    sta ($6A),y
    iny
    bne .u
.w:
    ldy #0
.l:
    cpy $45
    beq .x
    lda BUF,x
    beq .x
    sta ($6C),y
    inx
    iny
    bne .l
.x:
    rts
'''

FIXC_SRC = '''
    org $F750       ; (fixed bank: unused bytes)
enname:         ; bank 12 $969E (enemy list, entry $4B): the name (as the Japanese); a
    jsr $9AAB   ;   name too wide for the list's 8 columns has compact tiles of its own
    lda #1      ;   (bank BT, table CNTAB by monster): they are written to free tile
    sta BOXF    ;   slots in a vertical blank and the name is made of their codes
    lda $4B
    bne .a
    sta CNEXT
.a:
    ldx $4B
    lda $7B4E,x
    asl a
    tay
    lda #BT
    jsr $FE1A
    lda CNTAB,y
    sta $6A
    lda CNTAB+1,y
    sta $6B
    ora $6A
    beq .x
    ldy #0
    lda ($6A),y
    sta CN_N
    clc
    adc CNEXT
    cmp #NSLOT+1
    bcs .x
    lda #1
    sta CN_P
    ldx #0
.t:
    cpx CN_N
    beq .s0
    jsr $FA2A   ; one tile per vertical blank (as the game streams monster tiles)
    txa
    clc
    adc CNEXT
    tay
    lda SLOTS,y
    pha
    lsr a
    lsr a
    lsr a
    lsr a
    sta $2006
    pla
    asl a
    asl a
    asl a
    asl a
    sta $2006
    ldy CN_P
.b:
    lda ($6A),y
    sta $2007
    iny
    tya
    and #$0F
    cmp #1
    bne .b
    sty CN_P
    jsr $FD46
    inx
    bne .t
.s0:
    ldy CN_P
    ldx #0
.s:
    lda ($6A),y
    beq .e
    cmp #9
    bcs .c
    clc
    adc CNEXT
    sty CN_P
    tay
    lda SLOTS-1,y
    ldy CN_P
.c:
    sta BUF,x
    iny
    inx
    bne .s
.e:
    sta BUF,x
    lda CNEXT
    clc
    adc CN_N
    sta CNEXT
.x:
    jmp $FA84
'''

FIXB_SRC = '''
    org $F850       ; (fixed bank: unused bytes)
copystr:        ; $DAF1: system string A to $7B00 for drawing (code 10 becomes the current
    sta $92     ;   character's code $9E), as the Japanese, with 16-bit pointers (English
    pha         ;   ($92: the id, for the one-row bitmap)
    lda #$0A    ;   menu strings exceed 256 bytes; $7C00-$7DFF is used only in battle)
    jsr $FE03
    pla
    asl a
    tay
    lda $8400,y
    sta $80
    lda $8401,y
    sta $81
    lda #0
    sta $82
    lda #$7B
    sta $83
    ldy #0
.l:
    lda ($80),y
    cmp #$30
    bcs .one
    cmp #$10
    bcc .one
    bne .two
    lda $9E
.two:
    sta ($82),y
    jsr .inc
    lda ($80),y
    sta ($82),y
    jsr .inc
    jmp .l
.one:
    sta ($82),y
    jsr .inc
    cmp #0
    bne .l
    lda #$0E
    jmp $FE03
.inc:
    iny
    bne .r
    inc $81
    inc $83
.r:
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

# battle boxes (bank 5 $AC02: width, height, top-left and bottom-left name table address):
# attacker, target, action, result, message. The Japanese 10/10/9/9/18 columns hold 8/8/7/7/16
# characters on the main row; English uses both interior rows (bconv) and wider boxes:
# names up to 12 letters a row ("Adamantaimai"), actions 13 ("Self-Destruct"), messages 26,
# laid out like the Japanese (the action boxes right of the name boxes sharing a border,
# the message box under both, as wide as the two).
BOXES = [(14, 0, 19), (14, 0, 22), (15, 13, 19), (15, 13, 22), (28, 0, 25)]
# text width per box ($44 = $45 before the conversion), at each place it is set
BOX_W = [(8, 12, [(12, 0xA9AC), (12, 0xA9C1), (12, 0xAC8A), (5, 0xA73B)]),
         (7, 13, [(12, 0xA9F7), (12, 0xAA1A), (12, 0xAA44), (12, 0xAA79)]),
         (16, 26, [(12, 0xA329), (12, 0xBED2), (5, 0xA520), (5, 0xA7AE)])]

def battle(rom, report, L):
    # text: bank 5 copied to bank BT_BANK, the three tables pointing to English strings
    rom[HDR + BT_BANK * BANK:HDR + (BT_BANK + 1) * BANK] = rom[HDR + 5 * BANK:HDR + 6 * BANK]
    b = Bank(rom, BT_BANK, [(0x8000, 0xAC44)])
    for name, table, n in (('monsters', 0xAC44, 128), ('battle_magic', 0xB0BB, 70), ('battle_msgs', 0xB295, 116)):
        rows = json.load(open('script/ff2/%s.json' % name))
        assert len(rows) == n
        for e in rows:
            b.put_ptr(table + 2 * e['id'], b.alloc(enc(e['en']) + b'\0'))
    # enemy list (8 columns, two rows a name): a word wider than 8 is drawn on compact tiles
    # (condensed letters); record: tile count, the tiles, the name with codes 1..n for them
    assert set(bank_get(rom, 5, CNTAB, 256)) != None
    for e in json.load(open('script/ff2/monsters.json')):
        n = e['en']; words = n.split(' ')
        rows = balanced(n, 8) if len(n) > 8 else [n]
        if len(rows) <= 2 and all(len(r) <= 8 for r in rows):
            bank_put(rom, BT_BANK, CNTAB + 2 * e['id'], b'\0\0'); continue
        rows = [n] if len(words) == 1 else [words[0], ' '.join(words[1:])]
        assert len(rows) == 2 or len(words) == 1
        tiles = []; text = bytearray()
        for r in rows:
            if text: text.append(0xFF)
            if len(r) <= 8: text += enc(r); continue
            t = left_label(r, True, fg=3, bg=2); assert len(t) <= 8, r
            text += bytes(range(len(tiles) + 1, len(tiles) + 1 + len(t))); tiles += t
        a = b.alloc(bytes([len(tiles)]) + b''.join(tiles) + bytes(text) + b'\0')
        bank_put(rom, BT_BANK, CNTAB + 2 * e['id'], bytes([a & 0xFF, a >> 8]))
    assert bank_get(rom, 12, 0x969E, 3) == b'\x20\xab\x9a'
    bank_put(rom, 12, 0x969E, jsr(L['enname']))
    report.append('battle text bank %d free: %d' % (BT_BANK, sum(y - x for x, y in b.free)))
    assert bank_get(rom, 31, 0xFD8C, 4) == b'\x8a\x20\x1a\xfe'
    bank_put(rom, 31, 0xFD8C, jsr(L['fdbank']) + b'\xEA')
    assert bank_get(rom, 31, 0xFDBD, 2) == b'\xe0\x11'
    bank_put(rom, 31, 0xFDBE, b'\x3F')                   # up to 63 bytes
    # the text buffer $7D47 (17 bytes) moves to ExRAM BUF
    refs = {5: [0xA4EE, 0xA4F4, 0xA4FA, 0xA500, 0xA506, 0xA72D, 0xA738],
            12: [0x9523, 0x9530, 0xAA11, 0xAA17, 0xAA64, 0xAA6A, 0xAA70, 0xAA76, 0xAA88,
                 0xAC6B, 0xAC76, 0xAD07, 0xAD1D, 0xAD23, 0xAD29, 0xBF30],
            31: [0xFDB6]}
    for bank, addrs in refs.items():
        for a in addrs:
            assert bank_get(rom, bank, a + 1, 2) == b'\x47\x7d', (bank, hex(a))
            bank_put(rom, bank, a + 1, bytes([BUF & 0xFF, BUF >> 8]))
    # box save stack: $7800 (224 bytes, sprite data from $78E0) to ExRAM SAVE
    assert bank_get(rom, 12, 0x90FA, 10).hex() == 'a9008d7c00a9788d7d00'
    bank_put(rom, 12, 0x90FB, bytes([SAVE & 0xFF])); bank_put(rom, 12, 0x9100, bytes([SAVE >> 8]))
    need = sum(w * 4 for w, _, _ in BOXES) + sum(w * 4 for w, _, _ in BOXES[:4])
    assert SAVE + sum(w * 4 for w, _, _ in BOXES) <= 0x6000
    for k, (w, x, y) in enumerate(BOXES):
        a = 0x2000 + y * 32 + x
        rec = bytes([w, 4, a & 0xFF, a >> 8, (a + 96) & 0xFF, (a + 96) >> 8])
        assert bank_get(rom, 5, 0xAC02 + 6 * k, 2) == bytes([[10, 10, 9, 9, 18][k], 4])
        bank_put(rom, 5, 0xAC02 + 6 * k, rec)
    # 'Magic can't be used' (19 letters) in the 21-column magic window: from column 1, not 4
    assert bank_get(rom, 12, 0x9EEE, 2) == b'\xa9\x58'
    bank_put(rom, 12, 0x9EEF, bytes([4 * 21 + 1]))
    # Gear window (bank 12 $A020, 21 columns, 8 rows): the Japanese two columns of 10 (hands
    # left, items right) cannot hold English names (up to 20 letters); one column, a row each:
    # Right Hand / its weapon / Left Hand / its weapon / Items / item 1 / item 2. The cursor
    # grid (2 x 2: hands, items) is kept; its positions (table $BFCD) follow the rows.
    # (row 0 stays blank, as the Japanese dakuten row above the first line)
    for a, old, new in ((0xA02B, 0x15, 21), (0xA036, 0x69, 63), (0xA041, 0x20, 105),
                        (0xA252, 0x40, 43), (0xA26D, 0x94, 85), (0xA298, 0x4B, 127), (0xA2AD, 0x75, 148)):
        assert bank_get(rom, 12, a, 2) == bytes([0xA9, old]), hex(a)
        bank_put(rom, 12, a + 1, bytes([new]))
    assert bank_get(rom, 12, 0xBFCD, 8).hex() == '48b848d8a0b8a0c8'
    bank_put(rom, 12, 0xBFCD, bytes([0x48, 0xB0, 0x48, 0xC0, 0x48, 0xD0, 0x48, 0xD8]))
    for old, new, sites in BOX_W:
        for bank, a in sites:
            assert bank_get(rom, bank, a, 2) == bytes([0xA9, old]), (bank, hex(a))
            bank_put(rom, bank, a + 1, bytes([new]))

def jsr(a): return bytes([0x20, a & 0xFF, a >> 8])
def jmp(a): return bytes([0x4C, a & 0xFF, a >> 8])

def engine(rom, report, sysbits):
    ex = asm(EXRAM_SRC, syms={'DB': DB_BANK, 'DA': DA_BANK, 'SB': SPLIT['dialogue_b'], 'SA': SPLIT['dialogue_a'], 'R0': ONE_ROW[0], 'R1': ONE_ROW[1], 'BT': BT_BANK})
    assert ex.org + len(ex.bytes) <= 0x6000
    rom[HDR + CODE_BANK * BANK:HDR + (CODE_BANK + 1) * BANK] = b'\xFF' * BANK
    img = bytearray(ex.bytes)
    k = ex.labels['SYSONE'] - ex.org; img[k:k + 32] = sysbits
    rom[HDR + CODE_BANK * BANK:HDR + CODE_BANK * BANK + len(img)] = img
    report.append('ExRAM code: %d bytes' % len(ex.bytes))
    L = dict(ex.labels)
    assert ex.org + len(ex.bytes) <= BUF, hex(ex.org + len(ex.bytes))
    for src, end in ((FIXA_SRC, 0xFFB0), (FIXB_SRC, 0xF900), (FIXC_SRC, 0xF800)):
        f = asm(src, syms=dict(L, BUF=BUF, BT=BT_BANK, CNTAB=CNTAB, NSLOT=17))
        assert f.org + len(f.bytes) <= end, (hex(f.org + len(f.bytes)))
        assert set(bank_get(rom, 31, f.org, len(f.bytes))) == {0}
        bank_put(rom, 31, f.org, f.bytes)
        report.append('fixed-bank code at %04X: %d bytes' % (f.org, len(f.bytes)))
        L.update(f.labels)
    f = asm(B12_SRC, syms=dict(L, BUF=BUF))
    assert f.org + len(f.bytes) <= 0x9683
    bank_put(rom, 12, f.org, f.bytes + b'\xEA' * (0x9683 - f.org - len(f.bytes)))
    report.append('bank 12 converter: %d bytes' % len(f.bytes))
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
    # main menu (system string 27): the hand cursor needs two cells before each English
    # command, which one line of 28 cannot give five of; the string has two lines of one
    # row each in the same window
    # item menu: the scrolling one-column list (EXRAM itemmenu); equipment screen's list
    # picker: one column (cursor step 4 bytes = 1 entry instead of 3)
    assert bank_get(rom, 14, 0xAEC5, 3) == b'\x20\x5e\x90'
    bank_put(rom, 14, 0xAEC5, jmp(L['itemmenu']))
    assert bank_get(rom, 14, 0xB082, 2) == b'\xa9\x0c'
    bank_put(rom, 14, 0xB082, b'\xa9\x04')
    assert bank_get(rom, 31, 0xDAF1, 3) == b'\x48\xa9\x0a'
    bank_put(rom, 31, 0xDAF1, jmp(L['copystr']))
    # one-column lists: shop sell, key words (ask), items (show)
    for a in (0x8FB7, 0x9216, 0x9393):
        assert bank_get(rom, 14, a, 2) == b'\xa9\x08', hex(a)
        bank_put(rom, 14, a, b'\xa9\x04')
    assert bank_get(rom, 31, 0xE9B2 + 2) == bytes([22])
    bank_put(rom, 31, 0xE9B2 + 2, bytes([24]))         # field window 2: 22 inside (to the screen edge: an
    # attribute block of its own; 23 would leave the border in the map palette)
    # shop buy list: below the prompt across the message window (was 12 columns right)
    assert bank_get(rom, 14, 0x9101, 3) == b'\xb9\x15\x91' and bank_get(rom, 14, 0x9110, 2) == b'\xc0\x24'
    t = L['shoptpl']
    bank_put(rom, 14, 0x9102, bytes([t & 0xFF, t >> 8])); bank_put(rom, 14, 0x9111, bytes([37]))
    assert bank_get(rom, 14, 0x90DB, 23).hex() == 'a538186 90c293f8538a5971869 0c8597a53c38e90c853c'.replace(' ', '')
    bank_put(rom, 14, 0x90DB, bytes.fromhex('a539186902853 9eaeaa59818690285 98a53d38e902853d'.replace(' ', '')))
    # field window 3 (money) two columns wider, to the screen edge (its border then has an
    # attribute block of its own, as window 2)
    for k, base, old, new in ((3, 0xE9B2, 12, 14),):
        assert bank_get(rom, 31, base + k) == bytes([old]), (k, hex(base))
        bank_put(rom, 31, base + k, bytes([new]))
    # battle text into its boxes (two rows for a long English text)
    # magic menu cursors: one column (step 4 bytes = 1 entry)
    for a in (0xAFA7, 0xAFC7):
        assert bank_get(rom, 14, a, 2) == b'\xa9\x08', hex(a)
        bank_put(rom, 14, a, b'\xa9\x04')
    # equipment screen: list window 12 (y 7) 16 rows high, picker window 13 below it
    WIN = {'y': 0xB4A5, 'h': 0xB4D7}
    for win, key, old, new in ((12, 'h', 12, 16), (13, 'y', 19, 23), (13, 'h', 10, 6)):
        assert bank_get(rom, 14, WIN[key] + win) == bytes([old]), (win, key)
        bank_put(rom, 14, WIN[key] + win, bytes([new]))
    # positions recorded by {15}-{17} (cursor spots, key words): one row up in one-row mode
    assert bank_get(rom, 31, 0xEC55, 5) == b'\xa5\x98\x18\x65\x1f'
    bank_put(rom, 31, 0xEC55, jsr(L['h_ypos']) + b'\xEA\xEA')
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
    battle(rom, report, L)

if __name__ == '__main__':
    rom = bytearray(open(sys.argv[1], 'rb').read())
    report = []
    for e in json.load(open('script/ff2/names.json')): NAMES[e['id']] = e['en']
    font(rom)
    guest_names(rom)
    b10 = insert_names(rom, report)
    sysbits = system_strings(rom, report, b10)
    put_table(rom, 'dialogue_b', [DB_BANK, DB_BANK + 1], 0x8000, report)
    put_table(rom, 'dialogue_a', [DA_BANK, DA_BANK + 1], 0x8000, report)
    put_table(rom, 'events', [EV_BANK], 0x8000, report)
    ending(rom, report)
    engine(rom, report, sysbits)
    open(sys.argv[2], 'wb').write(rom)
    print('\n'.join(report))
