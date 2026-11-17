#!/bin/bash
# Build a patched cynes (headless NES emulator): 512KB MMC1 (SUROM) + minimal MMC5,
# env PPU_LOG=1 logs every $2007 write with CPU address and PRG bank ($5115),
# env COV_LOG=FILE accumulates a code-coverage map (see src/cpu.cpp in the patch),
# needed for Final Fantasy I・II and the split MMC5 ROMs. Usage: build_emu.sh OUTDIR   then PYTHONPATH=OUTDIR
set -e
OUT=$(realpath -m "${1:-build/emu}")
HERE=$(dirname "$(realpath "$0")")
TMP=$(mktemp -d)
git clone -q https://github.com/Youlixx/cynes.git "$TMP/cynes"
cd "$TMP/cynes" && git checkout -q "$(cat "$HERE/CYNES_COMMIT")"
git apply "$HERE/cynes.patch"
pip install -q pybind11
INC=$(python3 -c "import pybind11;print(pybind11.get_include())")
PYINC=$(python3 -c "import sysconfig;print(sysconfig.get_paths()['include'])")
EXT=$(python3 -c "import sysconfig;print(sysconfig.get_config_var('EXT_SUFFIX'))")
mkdir -p "$OUT/cynes"; cp cynes/*.py "$OUT/cynes/"
g++ -O2 -std=c++17 -shared -fPIC -Isrc -I"$INC" -I"$PYINC" -DPYTHON_MODULE_VERSION='"patched"' src/*.cpp -o "$OUT/cynes/emulator$EXT"
echo "built: $OUT/cynes"
