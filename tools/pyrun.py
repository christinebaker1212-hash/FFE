"""Run one of the tool scripts as its own process: with this Python, or, inside the frozen
builder (tools/builder/ffe_builder.py, PyInstaller), through the builder executable
(`FFE-Builder.exe --run script.py args`)."""
import os, sys

ROOT = getattr(sys, '_MEIPASS', None) or os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))


def script_cmd(script, *args):
    """command line running tools script `script` (path relative to ROOT or absolute)"""
    path = script if os.path.isabs(script) else os.path.join(ROOT, script)
    if getattr(sys, 'frozen', False):
        return [sys.executable, '--run', path] + [str(a) for a in args]
    return [sys.executable, path] + [str(a) for a in args]


def run_script(argv):
    """`--run script args`: run a tools script in this process (frozen builder)"""
    import runpy
    script = argv[0]
    sys.argv = [script] + argv[1:]
    sys.path.insert(0, os.path.dirname(script))
    runpy.run_path(script, run_name='__main__')
