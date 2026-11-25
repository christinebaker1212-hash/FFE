"""Two-pass SM83 (Game Boy CPU) assembler, multi-bank, RGBDS-like syntax.

    r = asm('''
        section bank 0, $0150
    start:  ld a, [hl+]         ; comment
            ldh [$FF40], a      ; or: ldh [rLCDC], a  /  ld [$FF00+c], a
    .loop:  dec b               ; local label (scoped to the last global label)
            jr nz, .loop
            call far_routine
            ld a, bank(far_routine)
            ret
    table:  db 1, 2, "AB", low(start), high(start)
            dw start, $1234
            ds 16               ; 16 zero bytes  (ds 16, $FF  to fill with $FF)
        section bank 3, $4000
    far_routine: ret
    ''', syms={'rLCDC': 0xFF40})
    r.banks        # {bank: bytearray}, each starting at the bank's base ($0000 / $4000)
    r.labels       # {name: address}
    r.label_bank   # {name: bank}
    r.sym_file()   # RGBDS .sym text ("bb:aaaa name"), read by BGB, Emulicious, SameBoy

Operands: registers a b c d e h l af bc de hl sp; memory [hl] [hl+] [hl-] [hli] [hld] [bc]
[de] [c] [n16]; conditions nz z nc c. Numbers $hex %bin dec 'c'. Expressions use
+ - * / % & | ^ << >> ~ ( ) and low() high() bank(). `name = expr` / `name equ expr` define
constants. `section bank N, $addr` starts or continues code in ROM bank N at $addr.
`section wram, $C000` / `section hram, $FF80` lay out RAM labels (ds only, no bytes).
"""
import re
PROTECT_RAM = []                 # (lo, hi) RAM ranges no lower section may run into (set by builds)
RAM_SECTIONS = []                # (start, end, line) of every RAM section after a build (for checks)

R8 = {'b': 0, 'c': 1, 'd': 2, 'e': 3, 'h': 4, 'l': 5, '[hl]': 6, 'a': 7}
R16 = {'bc': 0, 'de': 1, 'hl': 2, 'sp': 3}
R16STK = {'bc': 0, 'de': 1, 'hl': 2, 'af': 3}
CC = {'nz': 0, 'z': 1, 'nc': 2, 'c': 3}
ALU = {'add': 0, 'adc': 1, 'sub': 2, 'sbc': 3, 'and': 4, 'xor': 5, 'or': 6, 'cp': 7}
CBROT = {'rlc': 0, 'rrc': 1, 'rl': 2, 'rr': 3, 'sla': 4, 'sra': 5, 'swap': 6, 'srl': 7}
CBBIT = {'bit': 0x40, 'res': 0x80, 'set': 0xC0}
SIMPLE = {'nop': [0x00], 'rlca': [0x07], 'rrca': [0x0F], 'rla': [0x17], 'rra': [0x1F],
          'daa': [0x27], 'cpl': [0x2F], 'scf': [0x37], 'ccf': [0x3F], 'halt': [0x76],
          'stop': [0x10, 0x00], 'di': [0xF3], 'ei': [0xFB], 'reti': [0xD9]}


class AsmError(Exception):
    pass


class Result:
    def __init__(self, banks, labels, label_bank):
        self.banks, self.labels, self.label_bank = banks, labels, label_bank

    def sym_file(self):
        rows = sorted((self.label_bank[n], a, n) for n, a in self.labels.items()
                      if n in self.label_bank)
        return ''.join('%02x:%04x %s\n' % (b, a, n) for b, a, n in rows)


def _num(tok):
    if tok.startswith('$'): return int(tok[1:], 16)
    if tok.startswith('%'): return int(tok[1:], 2)
    if tok.startswith("'"): return ord(tok[1])
    return int(tok)


def _split_args(s):
    out, depth, cur, q = [], 0, '', False
    for ch in s:
        if ch == '"': q = not q
        if not q and ch in '([': depth += 1
        if not q and ch in ')]': depth -= 1
        if ch == ',' and depth == 0 and not q:
            out.append(cur.strip()); cur = ''
        else:
            cur += ch
    if cur.strip(): out.append(cur.strip())
    return out


def asm(src, syms=None):
    """Assemble; a `jr` that does not reach is relaxed to `jp` and the source re-assembled."""
    promote = set()
    while True:
        try:
            return _asm_once(src, syms, promote)
        except _JrRange as e:
            promote.add(e.lineno)


class _JrRange(Exception):
    def __init__(self, lineno): self.lineno = lineno


def _asm_once(src, syms, promote):
    base_syms = dict(syms or {})
    lines = []
    for n, raw in enumerate(src.split('\n'), 1):
        line = re.sub(r";(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$).*", '', raw).rstrip()
        if line.strip(): lines.append((n, line))
    labels = {}; bank_of = {}
    for pass_no in (1, 2):
        syms = dict(base_syms); syms.update(labels)
        banks = {}; label_bank = {}
        cur = None; pc = 0; bank = None; scope = ''
        ram = False

        def ev(expr):
            expr = expr.strip()
            toks = re.findall(r"\$[0-9A-Fa-f]+|%[01]+|'.'|\.?[A-Za-z_][A-Za-z_0-9.]*|\d+|<<|>>|[-+*/%&|^~()]",
                              expr)
            if ''.join(toks).replace(' ', '') != expr.replace(' ', ''):
                raise AsmError('bad expression: ' + expr)
            py = ''; i = 0
            while i < len(toks):
                t = toks[i]
                if t in ('low', 'high', 'bank') and i + 1 < len(toks) and toks[i + 1] == '(':
                    depth = 0; j = i + 1
                    while True:
                        if toks[j] == '(': depth += 1
                        if toks[j] == ')':
                            depth -= 1
                            if depth == 0: break
                        j += 1
                    inner = ' '.join(toks[i + 2:j])
                    if t == 'bank':
                        name = scope + inner if inner.startswith('.') else inner
                        if name in label_bank: v = label_bank[name]
                        elif name in bank_of: v = bank_of[name]
                        elif pass_no == 1: v = 0
                        else: raise AsmError('bank of unknown label: ' + name)
                    else:
                        v = ev(inner); v = v & 0xFF if t == 'low' else (v >> 8) & 0xFF
                    py += str(v); i = j + 1; continue
                if t in ('<<', '>>') or t in '+-*%&|^~()': py += t
                elif t == '/': py += '//'
                elif t[0] in "$%'" or t[0].isdigit(): py += str(_num(t))
                else:
                    name = scope + t if t.startswith('.') else t
                    if name in syms: py += str(syms[name])
                    elif pass_no == 2: raise AsmError('undefined: ' + name)
                    else: py += '0'
                i += 1
            return eval(py)

        def emit(bs):
            nonlocal pc
            if ram: raise AsmError('code in a RAM section')
            if cur is None: raise AsmError('no section')
            off = pc - (0 if bank == 0 else 0x4000)
            if not 0 <= off < 0x4000 or off + len(bs) > 0x4000:
                raise AsmError('bank %d overflow at $%04X' % (bank, pc))
            if len(cur) < off: cur.extend(b'\xff' * (off - len(cur)))
            for k, b in enumerate(bs):
                if off + k < len(cur):
                    if pass_no == 2 and cur[off + k] != 0xFF and cur[off + k] != b and claimed.get((bank, off + k)):
                        raise AsmError('overlap at %02X:%04X' % (bank, pc + k))
                    cur[off + k] = b
                else:
                    cur.append(b)
                claimed[(bank, off + k)] = True
            pc += len(bs)

        claimed = {}
        consts = {}
        for lineno, line in lines:
            try:
                m = re.match(r'^\s*([A-Za-z_][A-Za-z_0-9]*)\s*(?:=|\s[eE][qQ][uU]\s)\s*(.+)$', line)
                if m:
                    v = ev(m.group(2))
                    if pass_no == 2 and m.group(1) in consts and consts[m.group(1)] != (lineno, m.group(2)):
                        raise AsmError('%s defined twice' % m.group(1))
                    consts[m.group(1)] = (lineno, m.group(2))
                    syms[m.group(1)] = v; continue
                m = re.match(r'^\s*([A-Za-z_.][A-Za-z_0-9.]*):(.*)$', line)
                if m:
                    name = m.group(1)
                    if not name.startswith('.'): scope = name
                    else: name = scope + name
                    if pass_no == 1 and name in labels:
                        raise AsmError('duplicate label ' + name)
                    labels[name] = pc; syms[name] = pc
                    if bank is not None: label_bank[name] = bank
                    line = m.group(2)
                    if not line.strip(): continue
                parts = line.strip().split(None, 1)
                mn = parts[0].lower(); arg = parts[1].strip() if len(parts) > 1 else ''
                args = _split_args(arg)
                if mn == 'section':
                    a0 = args[0].split()
                    if a0[0].lower() == 'bank':
                        if ram and pass_no == 2: RAM_SECTIONS.append((ram_sec, pc, ram_line))
                        bank = ev(a0[1]); pc = ev(args[1]); ram = False
                        if not ((bank == 0 and pc < 0x4000) or (bank > 0 and 0x4000 <= pc < 0x8000)):
                            raise AsmError('address $%04X not in bank %d' % (pc, bank))
                        cur = banks.setdefault(bank, bytearray())
                    else:
                        if ram and pass_no == 2: RAM_SECTIONS.append((ram_sec, pc, ram_line))
                        ram = True; bank = None; cur = None; pc = ev(args[1]); ram_sec = pc
                        ram_line = lineno
                    continue
                if mn == 'db':
                    out = []
                    for it in args:
                        if it.startswith('"'): out += list(it[1:-1].encode('latin-1'))
                        else: out.append(ev(it) & 0xFF)
                    emit(out); continue
                if mn == 'dw':
                    out = []
                    for it in args:
                        v = ev(it); out += [v & 0xFF, (v >> 8) & 0xFF]
                    emit(out); continue
                if mn == 'ds':
                    n = ev(args[0])
                    if ram:
                        # (protected RAM: a section that starts below a protected range must
                        # not run into it; the FF1 native build's save page, see PROTECT_RAM)
                        for lo, hi in PROTECT_RAM:
                            if ram_sec < lo and pc + n > lo:
                                raise AsmError('RAM section from $%04X runs into $%04X-$%04X'
                                               % (ram_sec, lo, hi))
                        pc += n
                    else: emit([ev(args[1]) & 0xFF if len(args) > 1 else 0] * n)
                    continue
                if mn == 'incbin_bytes':      # used by build scripts: incbin_bytes <sym of bytes>
                    emit(list(base_syms[args[0]])); continue
                if mn == 'jr' and lineno in promote: mn = 'jp'
                try:
                    emit(encode(mn, args, ev, pc, pass_no))
                except AsmError as e:
                    if mn == 'jr' and 'jr out of range' in str(e): raise _JrRange(lineno)
                    raise
            except _JrRange:
                raise
            except AsmError as e:
                raise AsmError('line %d: %s\n  %s' % (lineno, e, line.strip()))
            except (KeyError, IndexError, ValueError, SyntaxError) as e:
                raise AsmError('line %d: cannot assemble (%s)\n  %s' % (lineno, e, line.strip()))
        bank_of = dict(label_bank)
    res = Result(banks, labels, label_bank)
    res.claimed = claimed                   # (bank, offset) -> True: the bytes code / data took
    return res


def _mem(a):
    """'[x]' or '(x)' → inner text, else None."""
    a = a.strip()
    if (a.startswith('[') and a.endswith(']')) or (a.startswith('(') and a.endswith(')') and
                                                   a[1:-1].strip().lower() in ('hl', 'hl+', 'hl-', 'hli', 'hld', 'bc', 'de', 'c')):
        return a[1:-1].strip()
    return None


def _r8(a):
    a = a.strip().lower()
    if a in R8: return R8[a]
    m = _mem(a)
    if m is not None and m.lower() == 'hl': return 6
    return None


def encode(mn, args, ev, pc, pass_no):
    la = [a.lower() for a in args]
    if mn in SIMPLE and not args: return SIMPLE[mn]
    if mn in ALU:
        if len(args) == 2:
            if la[0] == 'a': args, la = args[1:], la[1:]
            elif mn == 'add' and la[0] == 'hl': return [0x09 | R16[la[1]] << 4]
            elif mn == 'add' and la[0] == 'sp': return [0xE8, ev(args[1]) & 0xFF]
        r = _r8(args[0])
        if r is not None: return [0x80 | ALU[mn] << 3 | r]
        return [0xC6 | ALU[mn] << 3, ev(args[0]) & 0xFF]
    if mn in ('inc', 'dec'):
        if la[0] in R16: return [(0x03 if mn == 'inc' else 0x0B) | R16[la[0]] << 4]
        return [(0x04 if mn == 'inc' else 0x05) | _r8(args[0]) << 3]
    if mn in CBROT:
        return [0xCB, CBROT[mn] << 3 | _r8(args[0])]
    if mn in CBBIT:
        b = ev(args[0])
        if not 0 <= b <= 7: raise AsmError('bit number')
        return [0xCB, CBBIT[mn] | b << 3 | _r8(args[1])]
    if mn in ('push', 'pop'):
        return [(0xC5 if mn == 'push' else 0xC1) | R16STK[la[0]] << 4]
    if mn == 'jr':
        if len(args) == 2: op = 0x20 | CC[la[0]] << 3; t = args[1]
        else: op = 0x18; t = args[0]
        d = ev(t) - (pc + 2)
        if pass_no == 2 and not -128 <= d <= 127: raise AsmError('jr out of range (%d)' % d)
        return [op, d & 0xFF]
    if mn in ('jp', 'call'):
        if mn == 'jp' and len(args) == 1 and (la[0] == 'hl' or _mem(la[0]) == 'hl'): return [0xE9]
        if len(args) == 2: op = (0xC2 if mn == 'jp' else 0xC4) | CC[la[0]] << 3; t = args[1]
        else: op = 0xC3 if mn == 'jp' else 0xCD; t = args[0]
        v = ev(t); return [op, v & 0xFF, (v >> 8) & 0xFF]
    if mn == 'ret':
        return [0xC0 | CC[la[0]] << 3] if args else [0xC9]
    if mn == 'rst':
        v = ev(args[0])
        if v & ~0x38: raise AsmError('rst vector')
        return [0xC7 | v]
    if mn == 'ldh':
        d, s = args
        md, ms = _mem(d), _mem(s)
        if md is not None and md.lower() in ('c', '$ff00+c', '$ff00 + c'): return [0xE2]
        if ms is not None and ms.lower() in ('c', '$ff00+c', '$ff00 + c'): return [0xF2]
        if md is not None and la[1] == 'a': op, e = 0xE0, md
        elif ms is not None and la[0] == 'a': op, e = 0xF0, ms
        else: raise AsmError('bad ldh')
        v = ev(e)
        if v >= 0xFF00: v -= 0xFF00
        if pass_no == 2 and not 0 <= v <= 0xFF: raise AsmError('ldh address out of range')
        return [op, v & 0xFF]
    if mn in ('ld', 'ldi', 'ldd'):
        d, s = args; ld, ls = d.lower(), s.lower()
        if mn != 'ld':                                   # ldi a,[hl] / ldd [hl],a
            ld = ld.replace('hl', 'hl+' if mn == 'ldi' else 'hl-'); ls = ls.replace('hl', 'hl+' if mn == 'ldi' else 'hl-')
        md, ms = _mem(ld), _mem(ls)
        idx = {'bc': 0x02, 'de': 0x12, 'hl+': 0x22, 'hli': 0x22, 'hl-': 0x32, 'hld': 0x32}
        if md in idx and ls == 'a': return [idx[md]]
        if ms in idx and ld == 'a': return [idx[ms] | 0x08]
        if md is not None and md in ('c', '$ff00+c', '$ff00 + c') and ls == 'a': return [0xE2]
        if ms is not None and ms in ('c', '$ff00+c', '$ff00 + c') and ld == 'a': return [0xF2]
        if ld == 'sp' and ls == 'hl': return [0xF9]
        if ld == 'hl' and re.match(r'^sp\s*[-+]', ls):
            v = ev(s.strip()[2:]); return [0xF8, v & 0xFF]
        if ld in R16:
            v = ev(s); return [0x01 | R16[ld] << 4, v & 0xFF, (v >> 8) & 0xFF]
        rd, rs = _r8(d), _r8(s)
        if rd is not None and rs is not None:
            if rd == 6 and rs == 6: raise AsmError('ld [hl],[hl]')
            return [0x40 | rd << 3 | rs]
        if md is not None and md != 'hl':
            if ls == 'sp': v = ev(d.strip()[1:-1]); return [0x08, v & 0xFF, v >> 8 & 0xFF]
            if ls == 'a': v = ev(d.strip()[1:-1]); return [0xEA, v & 0xFF, v >> 8 & 0xFF]
            raise AsmError('bad store')
        if ms is not None and ms != 'hl':
            if ld == 'a': v = ev(s.strip()[1:-1]); return [0xFA, v & 0xFF, v >> 8 & 0xFF]
            raise AsmError('bad load')
        if rd is not None:
            return [0x06 | rd << 3, ev(s) & 0xFF]
        raise AsmError('bad ld')
    raise AsmError('unknown instruction ' + mn)


# ---------------------------------------------------------------- cartridge image

NINTENDO_LOGO = bytes.fromhex(
    'CEED6666CC0D000B03730083000C000D0008111F8889000EDCCC6EE6DDDDD999'
    'BBBB67636E0EECCCDDDC999FBBB9333E')


def make_rom(banks, title, cart_type, rom_banks, ram_size_code, sgb=False, cgb=None):
    """Assemble banks into a ROM image with a valid header.
    cart_type: e.g. 0x1B = MBC5+RAM+BATTERY. rom_banks: power of two >= 2.
    cgb: None (DMG), 0x80 (works on both), 0xC0 (CGB only)."""
    rom = bytearray(b'\xff' * (rom_banks * 0x4000))
    for b, data in banks.items():
        if b >= rom_banks: raise AsmError('bank %d beyond ROM size' % b)
        rom[b * 0x4000: b * 0x4000 + len(data)] = data
    rom[0x104:0x134] = NINTENDO_LOGO
    t = title.encode('ascii')[:15 if cgb else 16]
    rom[0x134:0x144] = t.ljust(16, b'\0')
    if cgb is not None: rom[0x143] = cgb
    rom[0x144:0x146] = b'00'
    rom[0x146] = 0x03 if sgb else 0x00
    rom[0x147] = cart_type
    rom[0x148] = {2: 0, 4: 1, 8: 2, 16: 3, 32: 4, 64: 5, 128: 6, 256: 7, 512: 8}[rom_banks]
    rom[0x149] = ram_size_code
    rom[0x14A] = 0x01                          # non-Japanese
    rom[0x14B] = 0x33                          # use new licensee code (required for SGB)
    rom[0x14C] = 0
    x = 0
    for i in range(0x134, 0x14D): x = (x - rom[i] - 1) & 0xFF
    rom[0x14D] = x
    rom[0x14E:0x150] = b'\0\0'
    s = sum(rom) & 0xFFFF
    rom[0x14E:0x150] = bytes([s >> 8, s & 0xFF])
    return rom


if __name__ == '__main__':
    import sys
    r = asm(open(sys.argv[1]).read())
    for b, d in sorted(r.banks.items()): print('bank %d: %d bytes' % (b, len(d)))
