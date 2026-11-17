"""Check asm_sm83 against PyBoy's opcode name table (an independent reference):
every one of the 245 base opcodes and 256 CB opcodes is assembled from its name and
compared with its number.  usage: test_asm.py"""
import os, re, sys, importlib.util
sys.path.insert(0, os.path.dirname(__file__))
from asm_sm83 import asm

spec = importlib.util.find_spec('pyboy')
src = open(os.path.join(os.path.dirname(spec.origin), 'core', 'opcodes.py')).read()
lens = [int(x) for x in re.findall(r'\d+', src[src.index('OPCODE_LENGTHS'):src.index('])', src.index('OPCODE_LENGTHS'))].split('[',1)[1])]
names = re.findall(r'"([^"]*)"', src[src.index('CPU_COMMANDS = ['):])[:512]

def conv(name):
    s = name.lower().replace('(', '[').replace(')', ']')
    s = s.replace('d16', '$1234').replace('a16', '$1234').replace('d8', '$12').replace('a8', '$12')
    s = re.sub(r'rst (\w\w)h', r'rst $\1', s)
    s = s.replace('stop 0', 'stop').replace('sp+r8', 'sp+5').replace('r8', '$4007')  # jr: pc $4000 +2 +5
    return s.replace(',', ', ')

bad = 0; n = 0
for op, name in enumerate(names):
    if not name or name.upper().startswith(('PREFIX', 'UNKNOWN', 'BREAKPOINT')): continue
    line = conv(name); want = bytes([0xCB, op - 256]) if op >= 256 else bytes([op])
    try:
        got = asm('section bank 1, $4000\n ' + line).banks[1]
    except Exception as e:
        print('%03X %-14s -> %-18s ERROR %s' % (op, name, line, e)); bad += 1; continue
    n += 1
    if bytes(got[:len(want)]) != want or len(got) != (2 if op >= 256 else lens[op]):
        print('%03X %-14s -> %-18s got %s' % (op, name, line, got.hex())); bad += 1
print('%d opcodes checked, %d bad' % (n, bad))
sys.exit(1 if bad else 0)
