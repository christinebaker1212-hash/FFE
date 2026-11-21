"""FF1 native build: text. The font is our own (tools/latin_font.py), the window frame
tiles come from the user's ROM (FF1's menu graphics, $F7-$FF); the English text comes from
the project's translation (translations/ff1_*.py), wrapped for the Game Boy layouts.
Native encoding: ASCII $20-$7E ('…' = $7F), frame tiles $10-$18 (FF1 $F7-$FF), controls:
$00 end, $0A next line, $0C next page (wait for A), $02 the item name (treasure)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
sys.path.insert(0, os.path.join(HERE, '..', '..', 'translations'))
import latin_font
import data

MENU_CHR = 0x8800                      # BANK_MENUCHR (9): FF1's menu tiles $80-$FF
WIN_PAL = (0x0F, 0x00, 0x01, 0x30)     # FF1's window colours: outside, border, inside, text
DMG_WIN = (3, 2, 3, 0)                 # DMG: black window, dark grey border, white text
DLG_W, DLG_H = 18, 6                   # dialogue box text area (the approved layout)


def code_of(ch):
    return 0x7F if ch == '…' else ord(ch)


def font_tiles(rom):
    """{code: NES tile} for the frame and the glyphs (colour 2 background, 3 ink)"""
    menu = rom.rd(9, MENU_CHR, 0x800)
    out = {}
    for i, t in enumerate(range(0xF7, 0x100)):
        out[0x10 + i] = menu[(t - 0x80) * 16:(t - 0x80) * 16 + 16]
    out[0x20] = menu[(0xFF - 0x80) * 16:(0xFF - 0x80) * 16 + 16]   # space = the blank inside
    for ch in latin_font.G:
        out[code_of(ch)] = latin_font.tile(ch, fg=3, bg=2)
    return out


def font_banks(rom):
    """the font for DMG (pre-shaded) and CGB (as it is), 128 tiles by code"""
    f = font_tiles(rom)
    dmg = bytearray(2048); cgb = bytearray(2048)
    for code, t16 in f.items():
        dmg[16 * code:16 * code + 16] = data.gb_tile(t16, DMG_WIN)
        cgb[16 * code:16 * code + 16] = data.gb_tile(t16)
    return bytes(dmg), bytes(cgb)


def win_palette():
    return b''.join(data.rgb555(c).to_bytes(2, 'little') for c in WIN_PAL)


def wrap(text, width=DLG_W):
    lines = []
    for para in text.split('\n'):
        line = ''
        for w in para.split(' '):
            if not w: continue
            if not line: line = w
            elif len(line) + 1 + len(w) <= width: line += ' ' + w
            else: lines.append(line); line = w
        if line: lines.append(line)
    return lines


def encode_dialogue(text):
    """reflowed as the GB layout (the Japanese breaks are layout breaks): 18 columns, pages of
    6 lines"""
    text = text.replace('{02}', '\x02' * 1)
    lines = wrap(text.replace('\n', ' '))
    out = bytearray()
    for i, ln in enumerate(lines):
        if i:
            out.append(0x0C if i % DLG_H == 0 else 0x0A)
        for ch in ln:
            out.append(0x02 if ch == '\x02' else code_of(ch))
    return bytes(out) + b'\0'


def dialogue_banks(bank0):
    """all dialogue: a table (256 x bank, address) at bank0 $4000, the strings after it and in
    the next banks (a string never crosses a bank): {bank: bytes}"""
    import ff1_dialogue
    tbl = bytearray(768); banks = {bank0: bytearray()}
    b, addr = bank0, 0x4300
    for k in range(256):
        s = encode_dialogue(ff1_dialogue.D.get(k, ''))
        if addr + len(s) > 0x8000:
            b += 1; addr = 0x4000; banks[b] = bytearray()
        tbl[3 * k:3 * k + 3] = bytes([b, addr & 0xFF, addr >> 8])
        banks[b] += s; addr += len(s)
    out = {}
    for bk, body in banks.items():
        start = 0x4300 if bk == bank0 else 0x4000
        blob = bytearray(b'\xff' * 0x4000)
        if bk == bank0: blob[0:768] = tbl
        blob[start - 0x4000:start - 0x4000 + len(body)] = body
        out[bk] = bytes(blob)
    return out
