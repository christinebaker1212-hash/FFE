"""Build the Game Boy (dual-mode DMG / SGB / CGB) FF2 English ROM from the user's own NES ROM.

usage: build.py ["Final Fantasy I, II (Japan).nes"] [--gb] [--release] [--out ROM] [--work DIR]
  --work: intermediate files (English NES ROMs, the source base) there (the builder's
      work folder); default: next to --out, source base in build/ff2
  --gb: with the GB screen layout (tools/gb2/layout.py): build/ff2_gb.nes -> build/ff2_gb.gb
  --release (with --gb): build/ff2_release.gb without test-only code (the runtime's ;[test]
      blocks: the test-runner pad input); check it with tools/gb2/lotcheck.py --release

1. NES ROM -> MMC5 split (tools/split/build_mmc5.py) -> English (tools/ff2/insert.py)
   = build/ff2_en.nes
2. source base (tools/gb2/ff2src.py --english -> build/ff2/src_en: listing + ROM; needs
   build/src/ff2, the everything8215 listing) -> code map (tools/gb2/ff2code.py)
3. translate (tools/gb2/translate.py) + runtime (tools/gb2/rt/*.s), assemble
4. ROM: bank 0 runtime, banks DATA.. = the NES banks, then code banks
Nothing game-specific is stored in the repo; everything comes from the NES ROM. The NES is
never run: the code map, the stack tricks and the dynamic jump targets come from the
disassembly (everything8215 listing) and the ROM's bytes, not from emulator coverage.
"""
import os, re, sys, glob, hashlib, subprocess, time
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'gb'))
from ff2code import CodeMap
from translate import Recompiler, emit_program, DATA, RT_TABLES
from asm_sm83 import asm, make_rom
import build as gb1                       # tools/gb/build.py: shared tables (APU, NES colours, border)

SHA1_FF12 = '4b22c2c88fc71eacf270ea51ef218944bb4c536a'
RT_FILES = ('runtime.s', 'apu.s', 'hle.s', 'ff2.s', 'dmg_shade.s', 'sgb.s', 'save.s', 'selmenu.s', 'native_layer.s')   # (ff2.s continues bank 0)


def selmenu_text():
    """the Select menu / suspend texts (owner's brief) as menu-font tiles for rt/selmenu.s:
    tile = code - $80 for the letters $80-$CF, blank $FF -> T_BLANK (88), $FE next line,
    $FF end; lines wrapped at 18 columns"""
    import textwrap
    sys.path.insert(0, os.path.join(ROOT, 'tools', 'ff2'))
    import insert as ins
    def tiles(text):
        out = []
        for k, line in enumerate(text.split('\n')):
            if k: out.append(0xFE)
            for c in ins.enc(line):
                assert c == 0xFF or 0x80 <= c < 0xD0, (text, c)
                out.append(88 if c == 0xFF else c - 0x80)
        return out + [0xFF]
    def wrap(t): return '\n'.join(textwrap.wrap(t, 18))
    T = dict(SMT_SEL='Options\nFormation\nSuspend',
             SMT_OPT='Battle Speed\nBGM Volume\nSFX Volume',
             SMT_SUS=wrap('Create a Suspend Point and return to the Title?') + '\n\n' +
                     wrap('Suspend points are retained when turning off the Power.'),
             SMT_YES='Yes', SMT_NO='No',
             SMT_CONT=wrap('Continue from Suspend point?'),
             SMT_LOST1=wrap('Continue from last save?') + '\n\n' + wrap('The suspend point will be lost!'),
             SMT_LOST2=wrap('Start a New Game?') + '\n\n' + wrap('The suspend point will be lost!'),
             SMT_BAD=wrap('The Suspend Point is damaged and cannot be used. It will be erased.') + '\n\n' +
                     wrap('Press the A Button.'))
    for k, v in T.items(): assert v.count('\n') <= 7, k
    out = 'section bank SGB_BANK, $7800\n'
    for k, v in T.items():
        out += '%s: db %s\n' % (k, ', '.join(str(x) for x in tiles(v)))
    return out, 'SM_DIG0 = %d\n' % (ins.ENC['0'] - 0x80)


def nes_english(src, out_dir, gb=False):
    out = os.path.join(out_dir, 'ff2_en.nes')
    if hashlib.sha1(open(src, 'rb').read()).hexdigest() != SHA1_FF12:
        raise SystemExit('not the expected Final Fantasy I・II (Japan) ROM: ' + src)
    sys.path.insert(0, os.path.join(ROOT, 'tools'))
    from pyrun import script_cmd
    subprocess.check_call(script_cmd(os.path.join(ROOT, 'tools', 'split', 'build_mmc5.py'), src, out_dir), cwd=ROOT)
    subprocess.check_call(script_cmd(os.path.join(ROOT, 'tools', 'ff2', 'insert.py'),
                                     os.path.join(out_dir, 'ff2_mmc5.nes'), out), cwd=ROOT)
    if gb:
        gbo = os.path.join(out_dir, 'ff2_gb.nes')
        subprocess.check_call(script_cmd(os.path.join(HERE, 'layout.py'), out, gbo), cwd=ROOT)
        return gbo
    return out


def source_base(src, nes, srcdir, gb=False):
    """build/ff2/src_en from the listing + ROM, unless it is already there for this ROM"""
    import json
    mp = os.path.join(srcdir, 'map.json')
    sha = hashlib.sha1(open(nes, 'rb').read()).hexdigest()
    tools = [os.path.join(HERE, f) for f in ('ff2src.py', 'ff2en.py', 'layout.py')] + \
        [os.path.join(ROOT, 'tools', 'ff2', 'insert.py')]
    fresh = os.path.exists(mp) and all(os.path.getmtime(t) <= os.path.getmtime(mp) for t in tools)
    if fresh and json.load(open(mp))['rom_sha1'] == sha: return
    listing = os.path.join(ROOT, 'build', 'src', 'ff2', 'ff2j.asm')
    if not os.path.exists(listing):
        raise SystemExit('everything8215 listing missing: git clone --depth 1 '
                         'https://github.com/everything8215/ff2 build/src/ff2')
    sys.path.insert(0, os.path.join(ROOT, 'tools'))
    from pyrun import script_cmd
    subprocess.check_call(script_cmd(os.path.join(HERE, 'ff2src.py'), src, srcdir, '--gb' if gb else '--english',
                                     '--listing', listing), cwd=ROOT)


def main():
    args = sys.argv[1:]
    gb = '--gb' in args
    if gb: args.remove('--gb')
    release = '--release' in args                   # release build: no test-only code
    if release:
        args.remove('--release')
        if not gb: raise SystemExit('--release needs --gb')
        if os.environ.get('GB_END_TEST'): raise SystemExit('--release: GB_END_TEST is a test build')
    opt = {'--out': os.path.join(ROOT, 'build', 'ff2_release.gb' if release else 'ff2_gb.gb' if gb else 'ff2_en.gb'),
           '--nes': None, '--work': None}
    pos = []
    while args:
        a = args.pop(0)
        if a in opt: opt[a] = args.pop(0)
        else: pos.append(a)
    src = pos[0] if pos else os.path.join(ROOT, 'roms', 'Final Fantasy I, II (Japan).nes')
    out_dir = os.path.dirname(os.path.abspath(opt['--out']))
    os.makedirs(out_dir, exist_ok=True)
    work = os.path.abspath(opt['--work']) if opt['--work'] else out_dir   # (intermediate files)
    os.makedirs(work, exist_ok=True)
    nes = opt['--nes'] or nes_english(src, work, gb)
    srcdir = os.path.join(work if opt['--work'] else os.path.join(ROOT, 'build'), 'ff2', 'src_gb' if gb else 'src_en')
    source_base(src, nes, srcdir, gb)
    ext_side = nes + '.ext.json'                    # native replacements of our own layout
    if os.path.exists(ext_side):                    #   routines (layout.NATIVE_EXT)
        import json, translate
        for name, (bank, addr, routine, flags) in json.load(open(ext_side)).items():
            translate.FF2.ext[('b%02d' % bank if bank != 31 else 'fix', addr)] = (routine, flags)
    t = time.time()
    cm = CodeMap(nes, srcdir).build()               # (the disassembly's code map; no coverage)
    rc = Recompiler(cm)
    prg = open(nes, 'rb').read()[16:]
    for k, code in getattr(rc.g, 'idiom_code', {}).items():   # fixed bank = bank 31
        off = 31 * 0x4000 + k[1] - 0xC000 if k[0] == 'fix' else \
            int(k[0][1:]) * 0x4000 + k[1] - 0x8000 if k[0].startswith('b') else None
        if off is None or prg[off:off + len(code)] != code or k not in cm.insns:
            print('  idiom %s:%04X: code not found, not used' % k); rc.g.idioms.pop(k, None)
    import ftrans                                   # function-level front end
    fp = ftrans.Program(rc)                         #   (docs/ff2-gb-function-translator.md)
    fp.check()
    prog, bank_of, banks = emit_program(rc, fp.compile())
    rt = '\n'.join(open(os.path.join(HERE, 'rt', f)).read() for f in RT_FILES)
    if release:                                     # ;[test] .. ;[/test]: test-runner paths
        rt = re.sub(r'^;\[test\].*?^;\[/test\][^\n]*\n', '', rt, flags=re.S | re.M)
    rt += '\n' + gb1.apu_tables() + '\n' + open(os.path.join(HERE, 'rt', 'apu_core.s')).read()
    rt += '\n' + open(os.path.join(HERE, 'rt', 'native.s')).read()
    rt += '\n' + open(os.path.join(HERE, 'rt', 'ff2_banked.s')).read()   # (continues bank HLE_BANK)
    rt += '\n' + open(os.path.join(HERE, 'rt', 'ff2_pal.s')).read()      # (bank 0 $39E0: CGB palettes)
    smt, sme = selmenu_text()                                           # (SGB bank $7800: menu texts;
    rt = sme + rt + '\n' + smt                                         #   the digit equate first)
    shade_src = 'section bank 0, $3F00\nshade_tab:\n' + ''.join(
        '    db %s\n' % ', '.join(str(gb1.shade(c)) for c in range(r, r + 16)) for r in range(0, 64, 16))
    src_all = rt + '\n' + shade_src + '\n' + gb1.nes_rgb_src() + '\n' + gb1.border_src() + '\n' + prog
    open(opt['--out'] + '.s', 'w').write(src_all)
    print('translated: %d instructions, %d code banks (%.1fs)' % (len(rc.insns), len(banks), time.time() - t))
    t = time.time()
    r = asm(src_all, syms={'DATA': DATA, 'RT_TABLES': RT_TABLES})
    print('assembled (%.1fs)' % (time.time() - t))
    for n in range(32):
        r.banks[DATA + n] = bytearray(prg[n * 0x4000:(n + 1) * 0x4000])
    top = max(r.banks) + 1
    size = 2
    while size < top: size *= 2
    rom = make_rom(r.banks, 'FF2 ENGLISH', cart_type=0x1B, rom_banks=size, ram_size_code=0x04, sgb=True,   # 128 KB RAM (suspend point)
                   cgb=0x80)                          # dual-mode: DMG / SGB / CGB
    open(opt['--out'], 'wb').write(rom)
    open(opt['--out'][:-3] + '.sym', 'w').write(r.sym_file())
    print('wrote %s: %d KB, bank 0 used %d bytes' % (opt['--out'], len(rom) // 1024, len(r.banks[0])))
    w = {}
    for x in rc.warn: w.setdefault(x.split(' at ')[0].split(' from ')[0][:40], []).append(x)
    open(opt['--out'] + '.warn', 'w').write('\n'.join(rc.warn) + '\n')
    for k, v in sorted(w.items(), key=lambda kv: -len(kv[1])):
        print('  warn %-42s x%d  e.g. %s' % (k, len(v), v[0][-40:]))


if __name__ == '__main__':
    main()
