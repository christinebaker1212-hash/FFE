#!/bin/bash
# Build a patched cynes (headless NES emulator) that supports 512KB MMC1 (SUROM),
# needed for Final Fantasy I・II. Usage: build_emu.sh OUTDIR   then PYTHONPATH=OUTDIR
set -e
OUT=$(realpath -m "${1:-build/emu}")
HERE=$(dirname "$(realpath "$0")")
TMP=$(mktemp -d)
git clone -q https://github.com/Youlixx/cynes.git "$TMP/cynes"
cd "$TMP/cynes" && git checkout -q "$(cat "$HERE/CYNES_COMMIT")"
git apply "$HERE/cynes-mmc1-surom.patch"
pip install -q pybind11
INC=$(python3 -c "import pybind11;print(pybind11.get_include())")
PYINC=$(python3 -c "import sysconfig;print(sysconfig.get_paths()['include'])")
EXT=$(python3 -c "import sysconfig;print(sysconfig.get_config_var('EXT_SUFFIX'))")
mkdir -p "$OUT/cynes"; cp cynes/*.py "$OUT/cynes/"
g++ -O2 -std=c++17 -shared -fPIC -Isrc -I"$INC" -I"$PYINC" -DPYTHON_MODULE_VERSION='"patched"' src/*.cpp -o "$OUT/cynes/emulator$EXT"
echo "built: $OUT/cynes"
