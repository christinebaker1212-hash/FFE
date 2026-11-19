"""Regenerate the recompiler's coverage logs for a NES ROM (needed after every change to
the NES code): new game + random play (covrun.py, seeds 1-4) and the field scripts below
(covfield.py) and battle input modes (covbattle.py), all in parallel, then one battle per
formation (128); as many runs at once as there are CPUs (env COV_JOBS); writes
OUTDIR/rom.sha1 (build.py warns on a mismatch).
usage: PYTHONPATH=build/emu covall.py ROM OUTDIR [FRAMES (random play, default 80000)]"""
import hashlib, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ITEMS = ('6021=1,6022=1,6023=1,6024=1,6025=1,6026=1,6027=1,6028=1,6029=1,602A=1,602B=1,'
         '602C=1,602D=1,602E=1,602F=1,6030=1,6031=1,6036=4,6037=2,6038=1,6039=63,603A=3,603B=7')
FIELD = [   # (name, script, frames, pokes)
    ('dialogue', 'U120,_30,U60,_60,U64,_10,R16,_10,U16,_10,R4,_10,A3,_200,A3,_120,A3,_120,A3,_100', 4700, ''),
    ('menu', '_30,S5,_80,D5,_30,A5,_80,B5,_40,D5,_20,D5,_20,A5,_120,B5,_60,B5,_60', 4300, ''),
    ('items', '_30,S5,_80,A5,_100,D5,_10,D5,_40,A5,_60,U5,_10,U5,_10,U5,_60,A5,_80'
              + ',D5,_10' * 14 + ',_80' + ',D5,_10' * 11 + ',_80,B5,_60,B5,_60', 4700, ITEMS),
    ('selmenu', '_30,T5,_90,A5,_90,R5,_10,R5,_10,D5,_10,L5,_10,D5,_10,L5,_30,B5,_90,D5,_10,A5,_200,B5,_100,_30,T5,_90,D5,_10,D5,_10,A5,_90,U5,_20,A5,_300,A5,_150,A5,_300', 4800, ''),
    ('magic', '_30,S5,_80,D5,_40,A5,_100,A5,_150,R5,_30,D5,_30,D5,_30,D5,_150,D5,_30,D5,_30,D5,_150,D5,_150,U5,_150,L5,_60,B5,_60,B5,_60', 4700, 'MAGIC'),
]
WEAPONS = '_30,S5,_80,D5,_40,D5,_40,A5,_150'
SCREENS = {     # menu sub-screen scripts (with magic_pokes), also used by the GB checks
    'equip': WEAPONS + ',A5,_40' + ',D5,_20' * 8 + ',_120,A5,_100,B5,_60,B5,_150',
    'swap': WEAPONS + ',R5,_40,A5,_60,A5,_40,D5,_40,A5,_120,B5,_60,B5,_150',
    'drop': WEAPONS + ',R5,_40,R5,_40,A5,_60,D5,_40,A5,_60,A5,_120,B5,_60,B5,_150',
    'armor': '_30,S5,_80,D5,_40,D5,_40,D5,_40,A5,_150,A5,_40' + ',D5,_20' * 8 + ',_120,A5,_100,B5,_60,B5,_150',
    'status': '_30,S5,_80,D5,_40,D5,_40,D5,_40,D5,_40,A5,_100,A5,_150,B5,_100,B5,_100',
}
FIELD += [(k, v, 4700, 'MAGIC') for k, v in SCREENS.items()]
SHOPS = {       # shop scripts: (shop index $51, input); the shop opens from the field pokes
    'shop_buy': (0x01, '_120,A5,_100,D5,_30,A5,_100,A5,_100,A5,_120,B5,_80'),
    'shop_sell': (0x01, '_120,D5,_30,A5,_100,A5,_100,D5,_30,A5,_100,A5,_120,B5,_80'),
    'shop_magic': (0x15, '_120,A5,_120,A5,_100,B5,_60,B5,_60'),
    'shop_inn': (0x33, '_120,A5,_200,A5,_250'),
    'shop_item': (0x3D, '_120,A5,_100,A5,_100,A5,_100,A5,_120,B5,_80'),
    'shop_church': (0x29, '_120,A5,_150,A5,_100'),
}
FIELD += [(k, v, 4700, 'MAGIC,0050=01,0051=%02X' % i) for k, (i, v) in SHOPS.items()]
FIELD += [('minimap', '_30,X8,_100,_100,A5,_60,B5,_100', 4300, ''),
          ('puzzle', '_6,Y20,_100,_100,R5,_40,D5,_40,L5,_40,U5,_40,B5,_100,_100', 4500, '0025=36,0042=04,0046=04')]
FIELD += [('lineup', '_30,T5,_100,A5,_40,D5,_30,A5,_100,B5,_100,_100,U30,_100,T5,_100,D5,_30,A5,_40,D5,_30,D5,_30,A5,_100,B5,_100,_300',
           4900, '')]   # Select: party order (its exit needs RTS-dispatch targets only this reaches)
FIELD += [('bridge', '_30,D16,_60,D16,_200,_200,A5,_200,A5,_200,A5,_200', 5200, '6016=01')]   # story pages
BATTLE = ['fight', 'run', 'fire1', 'cure4', 'magic4', 'items4', 'med1']     # battleseq.py modes


def pokes_of(p):
    """a FIELD entry's pokes: 'MAGIC' stands for magic_pokes()"""
    return magic_pokes() + p[5:] if p.startswith('MAGIC') else p


def magic_pokes():
    """spells and MP for all four members, weapons and armour in every slot"""
    p = []
    for m in range(4):
        for L in range(8):
            for s in range(3): p.append('%04X=%02X' % (0x6300 + 0x40 * m + 4 * L + s, s + 1 + L % 3))
            p.append('%04X=09' % (0x6320 + 0x40 * m + L)); p.append('%04X=09' % (0x6328 + 0x40 * m + L))
        for k in range(4):
            p.append('%04X=%02X' % (0x6118 + 0x40 * m + k, (0x80 if k == 0 else 0) | (1 + 5 * k + m)))
            p.append('%04X=%02X' % (0x611C + 0x40 * m + k, (0x80 if k == 0 else 0) | (1 + 7 * k + m)))
    return ','.join(p)


def main():
    rom, out = sys.argv[1], sys.argv[2]
    frames = sys.argv[3] if len(sys.argv) > 3 else '80000'
    sys.path.insert(0, os.path.join(HERE, '..'))
    from pyrun import script_cmd
    os.makedirs(out, exist_ok=True)
    env = dict(os.environ)
    jobs = []                                 # (command, COV_LOG, log file)
    for seed in (1, 2, 3, 4):                 # new game + random play
        jobs.append((script_cmd(os.path.join(HERE, 'covrun.py'), rom, seed, frames), 's%d' % seed))
    for i, (name, script, n, pokes) in enumerate(FIELD):
        cmd = script_cmd(os.path.join(HERE, 'covfield.py'), rom, script, n)
        if pokes: cmd += ['--poke', pokes_of(pokes)]
        jobs.append((cmd, 's%d' % (5 + i)))
    for i, mode in enumerate(BATTLE):
        jobs.append((script_cmd(os.path.join(HERE, 'covbattle.py'), rom, mode, 7700, '--poke', magic_pokes()), 'b%d' % i))
    for f in range(128):                      # every battle formation once (fight)
        jobs.append((script_cmd(os.path.join(HERE, 'covbattle.py'), rom, 'fight', 7000, '--poke', magic_pokes(),
                                '--form', f), 'f%03d' % f))
    workers = max(2, int(os.environ.get('COV_JOBS', '0')) or (os.cpu_count() or 4))
    bad, running, done = [], [], 0
    while jobs or running:
        while jobs and len(running) < workers:
            cmd, name = jobs.pop(0)
            log = os.path.join(out, name + '.bin')
            if os.path.exists(log): os.remove(log)
            running.append(subprocess.Popen(cmd, env=dict(env, COV_LOG=log),
                                            stdout=open(os.path.join(out, name + '.log'), 'w'),
                                            stderr=subprocess.STDOUT))
        p = running.pop(0)
        if p.wait() != 0: bad.append(p.args)
        done += 1
        print('coverage: %d of %d runs' % (done, done + len(jobs) + len(running)), flush=True)
    sha = hashlib.sha1(open(rom, 'rb').read()).hexdigest()
    with open(os.path.join(out, 'rom.sha1'), 'w') as fh: fh.write('%s  %s\n' % (sha, rom))
    shutil.copyfile(rom, os.path.join(out, 'rom.nes'))   # (build.py: drop coverage of changed bytes)
    print('coverage written to', out, 'failed:', bad)


if __name__ == '__main__':
    main()
