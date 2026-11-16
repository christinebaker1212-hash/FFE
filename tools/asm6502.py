"""Small two-pass 6502 assembler for the patches (official opcodes only).

    code = asm('''
        org $8000
    start:  lda #$0A        ; comment
            sta $57
            jsr $FE03
    .loop:  dey             ; local label (scoped to the last global label)
            bne .loop
            lda table,x
            rts
    table:  .db 1, 2, "AB", <start, >start
            .dw start, $1234
    ''', syms={'EXT': 0x5C00})
    code.bytes, code.labels, code.org

Syntax: one instruction per line, `label:` prefix, `;` comments, numbers $hex/%bin/dec/'c',
expressions with + - * and < (low byte) > (high byte), `name = expr` constants,
`org expr`. Zero-page modes are chosen automatically when the operand value is < $100
and known in pass 1 (use `a:` prefix, e.g. `lda a:$0012`, to force absolute).
"""
import re, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from dis6502 import OPS

OPC = {(mn, md): op for op, (mn, md) in OPS.items()}
BRANCH = {'BPL', 'BMI', 'BVC', 'BVS', 'BCC', 'BCS', 'BNE', 'BEQ'}

class Result:
    def __init__(self, org, data, labels): self.org, self.bytes, self.labels = org, bytes(data), labels

def _num(tok):
    if tok.startswith('$'): return int(tok[1:], 16)
    if tok.startswith('%'): return int(tok[1:], 2)
    if tok.startswith("'") and tok.endswith("'") and len(tok) == 3: return ord(tok[1])
    return int(tok)

def asm(src, syms=None, org=0x8000):
    syms = dict(syms or {})
    lines = []
    for raw in src.split('\n'):
        line = raw.split(';')[0].rstrip()
        if line.strip(): lines.append(line)
    for pass_no in (1, 2):
        pc = org; out = bytearray(); scope = ''; start = None
        def ev(expr, need=True):
            expr = expr.strip()
            if expr.startswith('<'): v = ev(expr[1:], need); return None if v is None else v & 0xFF
            if expr.startswith('>'): v = ev(expr[1:], need); return None if v is None else (v >> 8) & 0xFF
            toks = re.findall(r"\$[0-9A-Fa-f]+|%[01]+|'.'|\.?[A-Za-z_][A-Za-z_0-9.]*|\d+|[-+*()]", expr)
            py = ''
            for t in toks:
                if t in '+-*()': py += t
                elif t[0] in "$%'" or t[0].isdigit(): py += str(_num(t))
                else:
                    name = scope + t if t.startswith('.') else t
                    if name in syms: py += str(syms[name])
                    elif pass_no == 2: raise SystemExit('undefined: %s' % name)
                    else: return None
            return eval(py)
        for line in lines:
            m = re.match(r'^\s*([A-Za-z_.][A-Za-z_0-9.]*)\s*=\s*(.+)$', line)
            if m:
                v = ev(m.group(2))
                if v is not None: syms[m.group(1)] = v
                continue
            m = re.match(r'^\s*([A-Za-z_.][A-Za-z_0-9.]*):(.*)$', line)
            if m:
                name = m.group(1)
                if not name.startswith('.'): scope = name
                else: name = scope + name
                if pass_no == 1:
                    if name in syms and syms[name] != pc: raise SystemExit('dup label ' + name)
                    syms[name] = pc
                line = m.group(2)
                if not line.strip(): continue
            parts = line.strip().split(None, 1)
            mn = parts[0].upper(); arg = parts[1].strip() if len(parts) > 1 else ''
            if mn == 'ORG':
                pc = ev(arg); org = pc if start is None else org
                if start is None: start = pc
                continue
            if start is None: start = pc
            if mn == '.DB':
                for item in re.findall(r'"[^"]*"|[^,]+', arg):
                    item = item.strip()
                    if item.startswith('"'): out += item[1:-1].encode('latin-1')
                    else:
                        v = ev(item); out.append((v or 0) & 0xFF)
                pc = start + len(out); continue
            if mn == '.DW':
                for item in arg.split(','):
                    v = ev(item) or 0; out += bytes([v & 0xFF, v >> 8])
                pc = start + len(out); continue
            if mn == '.DS':
                out += bytes(ev(arg)); pc = start + len(out); continue
            # instruction
            force_abs = False
            a = arg
            if a.lower().startswith('a:'): force_abs = True; a = a[2:]
            if mn in BRANCH:
                t = ev(a); d = 0 if t is None else t - (pc + 2)
                if pass_no == 2 and not -128 <= d <= 127: raise SystemExit('branch out of range: ' + line)
                out += bytes([OPC[(mn, 'rel')], d & 0xFF])
            elif a == '' or a.upper() == 'A':
                md = 'acc' if (mn, 'acc') in OPC else 'imp'
                out.append(OPC[(mn, md)])
            elif a.startswith('#'):
                v = ev(a[1:]); out += bytes([OPC[(mn, 'imm')], (v or 0) & 0xFF])
            else:
                m2 = re.match(r'^\((.+),\s*[xX]\)$', a); m3 = re.match(r'^\((.+)\),\s*[yY]$', a)
                m4 = re.match(r'^\((.+)\)$', a); m5 = re.match(r'^(.+),\s*([xXyY])$', a)
                if m2: v = ev(m2.group(1)); out += bytes([OPC[(mn, 'izx')], (v or 0) & 0xFF])
                elif m3: v = ev(m3.group(1)); out += bytes([OPC[(mn, 'izy')], (v or 0) & 0xFF])
                elif m4: v = ev(m4.group(1)) or 0; out += bytes([OPC[(mn, 'ind')], v & 0xFF, v >> 8])
                else:
                    if m5: expr, reg = m5.group(1), m5.group(2).lower()
                    else: expr, reg = a, ''
                    v = ev(expr)
                    zp = {'': 'zp', 'x': 'zpx', 'y': 'zpy'}[reg]; ab = {'': 'abs', 'x': 'abx', 'y': 'aby'}[reg]
                    # zero page only if the value is known in pass 1 and small (sizes must not change)
                    use_zp = not force_abs and v is not None and v < 0x100 and (mn, zp) in OPC
                    key = (id(src), start, len(out))
                    if pass_no == 1: _ZP[key] = use_zp
                    else: use_zp = _ZP.get(key, use_zp)
                    if use_zp: out += bytes([OPC[(mn, zp)], v & 0xFF])
                    else:
                        v = v or 0; out += bytes([OPC[(mn, ab)], v & 0xFF, (v >> 8) & 0xFF])
            pc = start + len(out)
    return Result(start if start is not None else org, out, syms)

_ZP = {}

if __name__ == '__main__':
    r = asm(open(sys.argv[1]).read())
    print('%04X' % r.org, r.bytes.hex())
