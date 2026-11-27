"""FFE Builder: makes the Game Boy versions of the English Final Fantasy translations from
the user's own NES ROM files. Nothing of the games is included: every game byte comes from
the ROM chosen here.

    FFE-Builder.exe                                  (window)
    FFE-Builder.exe --cli ROM OUTDIR [FF3ROM [GBAROM]] (console: FF1; the GBA ROM: the post-game)
    FFE-Builder.exe --cli ROM OUTDIR --recompiled    (the earlier recompiled build)

Steps for Final Fantasy I (Game Boy / Super Game Boy / Game Boy Color): check the ROM's
SHA-1, split the FF I・II ROM into MMC5 ROMs (tools/split/build_mmc5.py), insert the
English script with the GB layout (tools/ff1/insert.py --gb), then build the native Game Boy
game (tools/gbn/build.py: our own engine, the game's data from the ROM; the FF III ROM, if
given, supplies the item and spell icons). The earlier recompiled build (--recompiled) makes
a code map by running the NES game in the bundled emulator (tools/gb/covall.py; ~15-40
minutes the first time) and recompiles it (tools/gb/build.py).
Final Fantasy II and III: not available yet."""
import hashlib, os, subprocess, sys, threading
# modules the bundled tools scripts import (run through runpy inside the frozen builder,
# where PyInstaller only packs what it sees imported here)
import bisect, collections, glob, json, math, random, re, runpy, struct, tempfile, time  # noqa: F401
try:
    import numpy, PIL.Image, PIL.ImageDraw, cynes  # noqa: F401
except ImportError:
    pass

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = getattr(sys, '_MEIPASS', None) or os.path.abspath(os.path.join(HERE, '..', '..'))   # (frozen: the bundle)
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from pyrun import script_cmd, run_script

SHA1_FF12 = '4b22c2c88fc71eacf270ea51ef218944bb4c536a'      # Final Fantasy I・II (Japan)
SHA1_FF3 = 'c4443fc24625e3c2bb859525eb44b6b3a80e7c35'       # Final Fantasy III (Japan)
GAMES = [('Final Fantasy I', 'ff1', SHA1_FF12, True),
         ('Final Fantasy II', 'ff2', SHA1_FF12, False),
         ('Final Fantasy III', 'ff3', SHA1_FF3, True)]     # (FF III: FF I's icons for now)


def sha1(path):
    return hashlib.sha1(open(path, 'rb').read()).hexdigest()


def run(cmd, log):
    log('> ' + ' '.join(os.path.basename(c) if os.path.isabs(c) and c.endswith('.py') else c for c in cmd[:4]) + ' ...')
    p = subprocess.Popen(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                         creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    for line in p.stdout: log(line.rstrip())
    if p.wait() != 0: raise RuntimeError('step failed: %s' % ' '.join(cmd[:4]))


SHA1_DOS = '3d1c580b9b3007f6f910d80f4c7421f5d2e19dbe'      # Final Fantasy I・II Advance (Japan) (Rev 1)


def build_ff1(rom, outdir, log, ff3=None, recompiled=False, gba=None):
    if recompiled:
        return build_ff1_recompiled(rom, outdir, log)
    if sha1(rom) != SHA1_FF12:
        raise RuntimeError('%s is not the expected "Final Fantasy I, II (Japan).nes" (SHA-1 %s)' % (rom, SHA1_FF12))
    work = os.path.join(outdir, 'ffe_work')
    os.makedirs(work, exist_ok=True)
    log('1/3 splitting the FF I・II ROM')
    run(script_cmd('tools/split/build_mmc5.py', rom, work), log)
    log('2/3 English script, Game Boy layout')
    nes = os.path.join(work, 'ff1_gb.nes')
    run(script_cmd('tools/ff1/insert.py', os.path.join(work, 'ff1_mmc5.nes'), nes, '--gb'), log)
    out = os.path.join(outdir, 'Final Fantasy I (English, GB).gb')
    args = ['--nes', nes, '--out', out]
    if ff3:
        if sha1(ff3) != SHA1_FF3:
            raise RuntimeError('%s is not the expected "Final Fantasy III (Japan).nes" (SHA-1 %s)' % (ff3, SHA1_FF3))
        args += ['--ff3', ff3]
    if gba:                                          # (the post-game: Dawn of Souls' shrines)
        if sha1(gba) != SHA1_DOS:
            raise RuntimeError('%s is not the expected "Final Fantasy I, II Advance (Japan) (Rev 1).gba" (SHA-1 %s)'
                               % (gba, SHA1_DOS))
        args += ['--gba', gba]
        log('3/3 the Game Boy game (icons from the FF III ROM)')
    else:
        log('3/3 the Game Boy game (no FF III ROM chosen: no item / spell icons)')
    run(script_cmd('tools/gbn/build.py', *args), log)
    log('done: ' + out)
    return out


def build_ff1_recompiled(rom, outdir, log):
    if sha1(rom) != SHA1_FF12:
        raise RuntimeError('%s is not the expected "Final Fantasy I, II (Japan).nes" (SHA-1 %s)' % (rom, SHA1_FF12))
    work = os.path.join(outdir, 'ffe_work')
    os.makedirs(work, exist_ok=True)
    log('1/4 splitting the FF I・II ROM')
    run(script_cmd('tools/split/build_mmc5.py', rom, work), log)
    log('2/4 English script, Game Boy layout')
    nes = os.path.join(work, 'ff1_gb.nes')
    run(script_cmd('tools/ff1/insert.py', os.path.join(work, 'ff1_mmc5.nes'), nes, '--gb'), log)
    cov = os.path.join(work, 'cov_ff1')
    shf = os.path.join(cov, 'rom.sha1')
    if os.path.exists(shf) and open(shf).read().split()[0] == sha1(nes):
        log('3/4 code map: kept from an earlier build')
    else:
        log('3/4 code map: playing the NES game in the emulator (first build only: this takes a while)')
        run(script_cmd('tools/gb/covall.py', nes, cov), log)
    log('4/4 recompiling for the Game Boy')
    out = os.path.join(outdir, 'Final Fantasy I (English, GB).gb')
    run(script_cmd('tools/gb/build.py', '--gb', '--release', '--nes', nes, '--cov', cov, '--out', out), log)
    log('done: ' + out)
    return out


def cli(argv):
    rec = '--recompiled' in argv
    argv = [a for a in argv if a != '--recompiled']
    rom, outdir = argv[0], argv[1] if len(argv) > 1 else os.getcwd()
    ff3 = argv[2] if len(argv) > 2 else None
    gba = argv[3] if len(argv) > 3 else None
    build_ff1(rom, outdir, lambda s: print(s, flush=True), ff3=ff3, recompiled=rec, gba=gba)


def gui():
    import tkinter as tk
    from tkinter import filedialog, scrolledtext
    w = tk.Tk(); w.title('FFE Builder'); w.geometry('720x480')
    tk.Label(w, text='Builds the English Game Boy versions from your own NES ROMs. '
                     'No game data is included.', anchor='w').pack(fill='x', padx=8, pady=(8, 2))
    rows = {}
    for title, key, sha, ok in GAMES:
        f = tk.Frame(w); f.pack(fill='x', padx=8, pady=2)
        tk.Label(f, text=title, width=18, anchor='w').pack(side='left')
        var = tk.StringVar(value='' if ok else 'not available yet')
        e = tk.Entry(f, textvariable=var, state='normal' if ok else 'disabled'); e.pack(side='left', fill='x', expand=True)
        b = tk.Button(f, text='NES ROM...', state='normal' if ok else 'disabled',
                      command=lambda v=var: v.set(filedialog.askopenfilename(filetypes=[('NES ROM', '*.nes'), ('all', '*.*')]) or v.get()))
        b.pack(side='left', padx=4)
        rows[key] = var
    gf = tk.Frame(w); gf.pack(fill='x', padx=8, pady=2)                  # (optional: the post-game)
    tk.Label(gf, text='Dawn of Souls (GBA)', width=18, anchor='w').pack(side='left')
    gbav = tk.StringVar(value='')
    tk.Entry(gf, textvariable=gbav).pack(side='left', fill='x', expand=True)
    tk.Button(gf, text='GBA ROM...', command=lambda: gbav.set(filedialog.askopenfilename(
        filetypes=[('GBA ROM', '*.gba'), ('all', '*.*')]) or gbav.get())).pack(side='left', padx=4)
    of = tk.Frame(w); of.pack(fill='x', padx=8, pady=2)
    tk.Label(of, text='Output folder', width=18, anchor='w').pack(side='left')
    outv = tk.StringVar(value=os.path.join(os.path.expanduser('~'), 'FFE'))
    tk.Entry(of, textvariable=outv).pack(side='left', fill='x', expand=True)
    tk.Button(of, text='Folder...', command=lambda: outv.set(filedialog.askdirectory() or outv.get())).pack(side='left', padx=4)
    txt = scrolledtext.ScrolledText(w, height=16); txt.pack(fill='both', expand=True, padx=8, pady=4)

    def log(s):
        w.after(0, lambda: (txt.insert('end', s + '\n'), txt.see('end')))

    def go():
        btn.config(state='disabled')

        def work():
            try:
                rom = rows['ff1'].get()
                if not rom: raise RuntimeError('choose the "Final Fantasy I, II (Japan).nes" file first')
                os.makedirs(outv.get(), exist_ok=True)
                build_ff1(rom, outv.get(), log, ff3=rows['ff3'].get() or None, gba=gbav.get() or None)
            except Exception as e:
                log('ERROR: %s' % e)
            finally:
                w.after(0, lambda: btn.config(state='normal'))
        threading.Thread(target=work, daemon=True).start()
    btn = tk.Button(w, text='Build Final Fantasy I for Game Boy', command=go); btn.pack(pady=(0, 8))
    w.mainloop()


def main():
    argv = sys.argv[1:]
    if argv[:1] == ['--run']:                 # a tools script, run by the frozen builder itself
        run_script(argv[1:]); return
    if argv[:1] == ['--cli']:
        cli(argv[1:]); return
    gui()


if __name__ == '__main__':
    import multiprocessing
    multiprocessing.freeze_support()
    main()
