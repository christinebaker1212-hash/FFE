"""Check the GB battle line writer (gb_layout.BOXLINE) on every battle message: run the
assembled 6502 code in py65 (pip install py65) with an 18-cell box row (the message
window interior) and compare the rows with a greedy word wrap. usage: test_boxline.py"""
import json, os, re, sys
sys.argv.append('--gb')
sys.path.insert(0, os.path.dirname(__file__)); sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
import insert, gb_layout
from asm6502 import asm
from py65.devices.mpu6502 import MPU

W, ROWS = 18, 4
INV = {v: k for k, v in insert.ENC.items()}
code = asm('    org $C000\n' + gb_layout.BOXLINE, syms=insert.EX)


def run(text):
    m = MPU(); mem = m.memory
    mem[0xC000:0xC000 + len(code.bytes)] = list(code.bytes)
    box = 0x6000
    for r in range(6):
        for c in range(32): mem[box + r * 32 + c] = 0
        mem[box + r * 32 + W] = 0xFA                       # right frame
    mem[0x8A], mem[0x8B] = box & 0xFF, box >> 8
    data = insert.enc(text)
    for i, b in enumerate(data): mem[0x6CD4 + 2 * i], mem[0x6CD5 + 2 * i] = 0xFF, b
    mem[0x6CD4 + 2 * len(data)] = mem[0x6CD5 + 2 * len(data)] = 0
    mem[0x5C0F] = 0
    mem[0x01FF], mem[0x01FE] = 0xFF, 0xFE                    # return to $FFFF
    m.sp, m.pc = 0xFD, code.labels['boxline']
    for _ in range(100000):
        if m.pc == 0xFFFF: break
        m.step()
    else: raise SystemExit('boxline did not return: %r' % text)
    rows = [''.join(INV.get(mem[box + r * 32 + c], '?') if mem[box + r * 32 + c] else ' ' for c in range(W)).rstrip()
            for r in range(ROWS + 1)]
    if mem[box + ROWS * 32] or any(mem[box + r * 32 + W] != 0xFA for r in range(6)):
        raise SystemExit('wrote outside the box: %r' % text)
    return [r for r in rows[:ROWS]], mem[0x5C0F]


def greedy(text):
    if '{FE}' in text: return sum((greedy(p) for p in text.split('{FE}')), [])
    rows, line = [], ''
    for w in text.split(' '):
        if not line: line = w
        elif len(line) + 1 + len(w) <= W: line += ' ' + w
        else: rows.append(line); line = w
    rows.append(line)
    return rows


bad = 0
msgs = [e['en'] for e in json.load(open('script/ff1/battle_msgs.json'))]
msgs += ["AAAA's party were wiped out", 'Magic power went up', 'Intelligence went up', 'Max HP 120 points', 'Giant{FE}Frog Lord', 'A long name that{FE}wraps']
for t in msgs:
    t = re.sub(r'\{(?!FE)..\}', 'AAAA', t).strip()
    if not t: continue
    rows, ovf = run(t)
    want = greedy(t)
    got = [r for r in rows if r]
    ok = got == want and not ovf and len(want) <= ROWS
    if not ok or len(want) > 2:
        print('OK ' if ok else 'BAD', len(want), '|'.join(rows), '' if ok else ' want ' + '|'.join(want))
    bad += not ok
print('messages:', len(msgs), 'bad:', bad)
sys.exit(1 if bad else 0)
