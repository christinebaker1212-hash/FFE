#!/bin/bash
# Build cynes for FF3 coverage work: tools/emu's patch (shared with FF1, unchanged) plus an
# FF3 tweak of the coverage index: FF3 runs MMC5 PRG mode 3 (8KB at $8000 by $5114 and at
# $A000 by $5115), while the shared index assumes FF1's 16KB bank at $8000 by $5115. Here
# the index is the 8KB-bank file offset for every window (bank * $2000 + pc & $1FFF), the
# fixed bank at $E000 being bank 127 of the 1MB ROM.
# Usage: build_emu.sh OUTDIR   then PYTHONPATH=OUTDIR
set -e
OUT=$(realpath -m "${1:-build/emu3}")
EMU=$(dirname "$(realpath "$0")")/../emu
TMP=$(mktemp -d)
git clone -q https://github.com/Youlixx/cynes.git "$TMP/cynes"
cd "$TMP/cynes" && git checkout -q "$(cat "$EMU/CYNES_COMMIT")"
git apply "$EMU/cynes.patch"
python3 - <<'P'
import glob
def sub(path, old, new):
    s = open(path).read(); assert s.count(old) == 1, (path, old); open(path, 'w').write(s.replace(old, new))
cpu = [p for p in glob.glob('src/*.cpp') if 'COV_RAM' in open(p).read()][0]
sub(cpu, "    if (pc >= 0x8000) return ((g_dbg_bank & 0x7F) >> 1) * 0x4000 + (pc - 0x8000);",
         "    if (pc >= 0xA000) return (g_dbg_bank & 0x7F) * 0x2000 + (pc - 0xA000);\n"
         "    if (pc >= 0x8000) return (g_dbg_bank_8 & 0x7F) * 0x2000 + (pc - 0x8000);")
sub(cpu, "    if (pc >= 0xE000) return 31 * 0x4000 + 0x2000 + (pc - 0xE000);",
         "    if (pc >= 0xE000) return 127 * 0x2000 + (pc - 0xE000);          // FF3: 1MB, bank 127")
sub(cpu, "extern int g_dbg_bank_c;", "extern int g_dbg_bank_c;\nextern int g_dbg_bank_8;")
m = [p for p in glob.glob('src/*.cpp') if 'g_dbg_bank_c = 0x80 + 62' in open(p).read()][0]
sub(m, "int g_dbg_bank_c = 0x80 + 62;", "int g_dbg_bank_8 = 0xFF;\nint g_dbg_bank_c = 0x80 + 62;")
sub(m, "if (address == 0x5115) g_dbg_bank = value;", "if (address == 0x5115) g_dbg_bank = value; if (address == 0x5114) g_dbg_bank_8 = value;")
P
pip install -q pybind11
INC=$(python3 -c "import pybind11;print(pybind11.get_include())")
PYINC=$(python3 -c "import sysconfig;print(sysconfig.get_paths()['include'])")
EXT=$(python3 -c "import sysconfig;print(sysconfig.get_config_var('EXT_SUFFIX'))")
mkdir -p "$OUT/cynes"; cp cynes/*.py "$OUT/cynes/"
g++ -O2 -std=c++17 -shared -fPIC -Isrc -I"$INC" -I"$PYINC" -DPYTHON_MODULE_VERSION='"patched-ff3"' src/*.cpp -o "$OUT/cynes/emulator$EXT"
echo "built: $OUT/cynes"
