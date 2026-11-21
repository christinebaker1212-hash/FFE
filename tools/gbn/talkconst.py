"""FF1 native build: the constants of FF1's talk routines, read from the user's ROM (the
immediate operands and save-RAM addresses of each routine, in code order), so the native
talk routines (src/talk.s) use the ROM's own object ids, battle formations, teleports and
item addresses. The routine of each object id is FF1's jump table entry (TalkToObject's
table, $90D3 in bank 14), named as the disassembly names it."""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
from nescode import OPS

LEN = {'imm': 2, 'zp': 2, 'zpx': 2, 'zpy': 2, 'abs': 3, 'abx': 3, 'aby': 3, 'ind': 3, 'izx': 2,
       'izy': 2, 'rel': 2, 'imp': 1, 'acc': 1}
JUMP_TBL, TALK_DATA, N_OBJ = 0x90D3, 0x95D5, 208
KINDS = ['Talk_None', 'Talk_KingConeria', 'Talk_Garland', 'Talk_Princess1', 'Talk_Bikke',
         'Talk_ElfDoc', 'Talk_ElfPrince', 'Talk_Astos', 'Talk_Nerrick', 'Talk_Smith', 'Talk_Matoya',
         'Talk_Unne', 'Talk_Vampire', 'Talk_Sarda', 'Talk_Bahamut', 'Talk_ifvis', 'Talk_SubEng',
         'Talk_CubeBot', 'Talk_Princess2', 'Talk_Fairy', 'Talk_Titan', 'Talk_CanoeSage', 'Talk_norm',
         'Talk_Replace', 'Talk_fight', 'Talk_Unused', 'Talk_ifitem', 'Talk_Invis', 'Talk_ifbridge',
         'Talk_ifevent', 'Talk_GoBridge', 'Talk_4Orb', 'Talk_CoOGuy', 'Talk_ifcanoe', 'Talk_ifcanal',
         'Talk_ifkeytnt', 'Talk_ifearthvamp', 'Talk_ifairship', 'Talk_ifearthfire', 'Talk_CubeBotBad',
         'Talk_Chime', 'Talk_BlackOrb']


def names_by_id(dis_dir):
    src = open(os.path.join(dis_dir, 'bank_0E.asm'), encoding='latin-1').read()
    i = src.index('lut_MapObjTalkJumpTbl:'); j = src.index(';;  Hide Map Object', i)
    names = re.findall(r'Talk_\w+', src[i:j])
    assert len(names) == N_OBJ
    return names


def routine_ops(b, at, starts=None):
    """{name: [(type, value, mnemonic)]}: immediates and absolute addresses of each routine
    (name -> address in the 16 KB bank image b), up to the next routine's start"""
    starts = sorted(set(starts or at.values()))
    ops = {}
    for n, a in at.items():
        end = min([s for s in starts if s > a] + [a + 0x60])
        out = []; i = a
        while i < end:
            op = b[i - 0x8000]
            if op not in OPS: break
            mn, md = OPS[op]; l = LEN[md]; arg = b[i - 0x8000 + 1:i - 0x8000 + l]
            if md == 'imm': out.append(('i', arg[0], mn))
            elif md in ('abs', 'abx', 'aby') and mn not in ('JSR', 'JMP'):
                out.append(('a', arg[0] | arg[1] << 8, mn))
            i += l
        ops[n] = out
    return ops


def item_routines(rom, dis_dir):
    """FF1's item menu jump table (found by its dispatch code in bank 14), named as the
    disassembly names it: {UseItem_x: ops}"""
    import re as _re
    b14 = rom.prg[14 * 0x4000:15 * 0x4000]
    t = None
    for m in _re.finditer(_re.escape(bytes([0x0A, 0xAA, 0xBD])), b14):
        i = m.start()
        if b14[i + 5:i + 7] == bytes([0x85, 0x10]) and b14[i + 12:i + 15] == bytes([0x6C, 0x10, 0x00]):
            t = b14[i + 3] | b14[i + 4] << 8
    assert t, 'item jump table not found'
    src = open(os.path.join(dis_dir, 'bank_0E.asm'), encoding='latin-1').read()
    i = src.index('@ItemJumpTable:'); j = src.index('UseItem_Bad:', i)
    names = _re.findall(r'UseItem_\w+', src[i:j])
    addr = [b14[t - 0x8000 + 2 * k] | b14[t - 0x8000 + 2 * k + 1] << 8 for k in range(len(names))]
    at = {}
    for n, a in zip(names, addr):
        assert at.setdefault(n, a) == a, n
    return routine_ops(b14, at), names


MAGIC_NAMES = ['CURE', 'CUR2', 'CUR3', 'CUR4', 'HEAL', 'HEL3', 'HEL2', 'PURE', 'LIFE', 'LIF2',
               'WARP', 'SOFT', 'EXIT']                   # the dispatch chain's order (disassembly)


def magic_routines(rom):
    """FF1's out-of-battle spells: the magic menu's dispatch chain (CMP #spell / BNE / JMP) in
    bank 14: ({name: spell id}, {name: ops}, no-MP text, can't-cast text)"""
    import re as _re
    b14 = rom.prg[14 * 0x4000:15 * 0x4000]
    for m in _re.finditer(b'\xc9', b14):
        j = m.start(); ch = []
        while b14[j] == 0xC9 and b14[j + 2:j + 4] == b'\xd0\x03' and b14[j + 4] == 0x4C:
            ch.append((b14[j + 1], b14[j + 5] | b14[j + 6] << 8)); j += 7
        if len(ch) == len(MAGIC_NAMES): break
    else:
        raise AssertionError('magic dispatch not found')
    assert b14[j] == 0xA9
    cant = b14[j + 1]
    k = m.start()
    while not (b14[k] == 0xA9 and b14[k + 2] == 0x20): k -= 1
    nomp = b14[k + 1]
    ids = {n: c[0] for n, c in zip(MAGIC_NAMES, ch)}
    at = {n: c[1] for n, c in zip(MAGIC_NAMES, ch)}
    return ids, routine_ops(b14, at), nomp, cant


def extract(rom, dis_dir):
    """(kind per object id, {kind: [(type, value)]}) from the ROM"""
    names = names_by_id(dis_dir)
    b14 = rom.prg[14 * 0x4000:15 * 0x4000]
    addr = [b14[JUMP_TBL - 0x8000 + 2 * k] | b14[JUMP_TBL - 0x8001 + 2 * k + 2] << 8 for k in range(N_OBJ)]
    at = {}
    for n, a in zip(names, addr):
        assert at.setdefault(n, a) == a, n
    starts = sorted(set(at.values()))
    ops = {}
    for n, a in at.items():
        end = min([s for s in starts if s > a] + [a + 0x60])
        out = []; i = a
        while i < end:
            op = b14[i - 0x8000]
            if op not in OPS: break
            mn, md = OPS[op]; l = LEN[md]; arg = b14[i - 0x8000 + 1:i - 0x8000 + l]
            if md == 'imm': out.append(('i', arg[0], mn))
            elif md in ('abs', 'abx', 'aby') and mn not in ('JSR', 'JMP'):
                out.append(('a', arg[0] | arg[1] << 8, mn))
            i += l
        ops[n] = out
    kind = bytes(KINDS.index(n) for n in names)
    return kind, ops


if __name__ == '__main__':
    sys.path.insert(0, HERE)
    import data
    r = data.Rom(sys.argv[1])
    k, ops = extract(r, os.path.join(HERE, '..', '..', 'build', 'ref', 'FF1Disassembly', 'Final Fantasy Disassembly'))
    for n in sorted(ops):
        print(n, ' '.join('%s%s:%s' % (t, ('%02X' % v) if t == 'i' else ('%04X' % v), m) for t, v, m in ops[n]))
