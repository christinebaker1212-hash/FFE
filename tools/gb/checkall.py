"""Run every RAM equivalence check (firstdiff.py) of the GB build against the NES build, on
DMG and CGB, as many at once as there are CPUs (env CHECK_JOBS): the new-game script, the
battle input modes (with spells poked), random play (seed 1, 30000 frames) and every field
script of covall.py (menus, sub-screens, shops, dialogue, Select menu, ...).
usage: PYTHONPATH=build/emu checkall.py NES GB [--only NAME,..] [--dmg | --cgb]
Prints one line per check and a summary; logs in build/checks/."""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import covall


def checks():
    out = [('newgame', ['3700'], ''), ('battle', ['7100', '--battle'], '')]
    for m in ('fire1', 'cure4', 'magic4', 'items4', 'med1', 'run'):
        out.append(('battle_' + m, ['7700', '--input', m], covall.magic_pokes()))
    out.append(('random1', ['30000', '--random', '1'], ''))
    for name, script, frames, pokes in covall.FIELD:
        out.append(('field_' + name, [str(frames), '--field', script], covall.pokes_of(pokes)))
    return out


def main():
    a = sys.argv[1:]
    nes, gb = a[0], a[1]
    only = a[a.index('--only') + 1].split(',') if '--only' in a else None
    modes = ['dmg'] if '--dmg' in a else ['cgb'] if '--cgb' in a else ['dmg', 'cgb']
    jobs = int(os.environ.get('CHECK_JOBS', os.cpu_count() or 2))
    logdir = os.path.join(HERE, '..', '..', 'build', 'checks')
    os.makedirs(logdir, exist_ok=True)
    todo = []
    for name, args, pokes in checks():
        if only and name not in only: continue
        for md in modes:
            cmd = [sys.executable, os.path.join(HERE, 'firstdiff.py'), nes, gb] + args
            if pokes: cmd += ['--poke', pokes]
            todo.append(('%s_%s' % (name, md), cmd, dict(os.environ, GB_CGB='1' if md == 'cgb' else '0')))
    running, results = [], []

    def finish(p):
        name, fh, path = p.ck
        p.wait(); fh.close()
        lines = [l for l in open(path).read().splitlines() if l.strip() and 'Warning' not in l and 'SDL2' not in l]
        last = lines[-1] if lines else '(no output)'
        ok = last.startswith('no difference')
        results.append((name, ok, last))
        print('%-28s %s  %s' % (name, 'OK  ' if ok else 'DIFF', last), flush=True)

    while todo or running:
        while todo and len(running) < jobs:
            name, cmd, env = todo.pop(0)
            path = os.path.join(logdir, name + '.log')
            fh = open(path, 'w')
            p = subprocess.Popen(cmd, env=env, stdout=fh, stderr=subprocess.STDOUT)
            p.ck = (name, fh, path)
            running.append(p)
        p = running.pop(0)
        finish(p)
    bad = [r for r in results if not r[1]]
    print('%d of %d checks identical' % (len(results) - len(bad), len(results)))
    for name, _, last in bad: print('  differs:', name, last)
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
