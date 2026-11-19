#!/bin/bash
# Build cynes for FF3 coverage work: tools/emu's patch (shared with FF1, unchanged) plus an
# FF3 tweak of the coverage index: FF3 runs MMC5 PRG mode 3 (8KB at $8000 by $5114 and at
# $A000 by $5115), while the shared index assumes FF1's 16KB bank at $8000 by $5115. Here
# the index is the 8KB-bank file offset for every window (bank * $2000 + pc & $1FFF), the
# fixed bank at $E000 being bank 127 of the 1MB ROM; and nmi_count / nmi_ram / pad_history
# count only NMIs through JMP $FF2A / JMP $FB57 in the RAM vector $0100 (FF3's frames).
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
# FF3 frames, as the GB runtime counts them: nmi_count / nmi_pad / pad_history count NMIs
# through JMP $FF2A (a wait) or JMP $FB57 (battle / cutscene handler) in the RAM vector
# $0100 (the input clock); ff3_waits / nmi_ram only those that end a wait ($FF2A, or $FB57
# taken in the $FB80 loop $FB82-$FB85): the RAM equivalence points
c2 = [p for p in glob.glob('src/*.cpp') if 'g_nmi_ram[k] = _nes.read_cpu(k);' in open(p).read()][0]
old = """            g_nmi_count++;
            g_nmi_pad = g_last_pad;
            g_pad_hist[g_nmi_count & 0xFF] = g_last_pad;
            for (int k = 0; k < 0x800; k++) g_nmi_ram[k] = _nes.read_cpu(k);"""
new = """            uint16_t ff3v = _nes.read_cpu(0x101) | _nes.read_cpu(0x102) << 8;
            if (_nes.read_cpu(0x100) == 0x4C && (ff3v == 0xFF2A || ff3v == 0xFB57)) {
            g_nmi_count++;
            g_nmi_pad = g_last_pad;
            g_pad_hist[g_nmi_count & 0xFF] = g_last_pad;
            if (ff3v == 0xFF2A || (_program_counter >= 0xFB82 && _program_counter < 0xFB86)) {
            g_ff3_waits++;
            for (int k = 0; k < 0x800; k++) g_nmi_ram[k] = _nes.read_cpu(k);
            }
            }"""
sub(c2, old, new)
sub(c2, "unsigned long g_nmi_count = 0;", "unsigned long g_nmi_count = 0;\nunsigned long g_ff3_waits = 0;")
wr = [p for p in glob.glob('src/*.cpp') + glob.glob('src/*.hpp') if '"nmi_count",' in open(p).read()][0]
sub(wr, '''            "nmi_count",''', '''            "ff3_waits",
            [](const wrapper::NesWrapper&) { extern unsigned long g_ff3_waits; return g_ff3_waits; },
            "FF3: NMIs that end a frame wait (the RAM equivalence points; nmi_ram is taken there)."
        )
        .def_property_readonly(
            "nmi_count",''')
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
