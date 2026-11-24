#include <fcntl.h>
#include <mgba/core/serialize.h>
#include <mgba-util/vfs.h>
/* Interactive headless mGBA runner: a test script (Python) drives the game closed-loop through
 * stdin / stdout, so it can react to what the game shows (positions, menus) instead of
 * replaying fixed presses. Used for play-throughs on DMG / SGB / CGB.
 *
 * usage: mgsh ROM [--dmg | --cgb | --model M]     (default: Super Game Boy with its border)
 * commands (one a line), each answered with one line:
 *   f N KEYS      run N frames holding KEYS (letters a b s t u d l r, or -)  -> "ok FRAME"
 *   r ADDR N      read N bytes from the bus (hex address)                    -> hex bytes
 *   s PATH        screenshot of the last frame (PPM; SGB: 256x224 with the border) -> "ok"
 *   v             VRAM / OAM writes outside their access windows so far (Lot Check 2.2)
 *   q             quit
 * Build: gcc -O2 tools/gb/mgba/mgsh.c -lmgba -o build/mgsh   (Ubuntu: apt install libmgba-dev)
 */
#include <mgba/core/core.h>
#include <mgba/core/config.h>
#include <mgba/internal/gb/gb.h>
#include <mgba/internal/sm83/sm83.h>
#include <mgba-util/vfs.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static unsigned parse_keys(const char* s) {
	unsigned k = 0;
	for (; *s; s++) switch (*s) {
		case 'a': k |= 1 << 0; break; case 'b': k |= 1 << 1; break;
		case 's': k |= 1 << 2; break; case 't': k |= 1 << 3; break;
		case 'r': k |= 1 << 4; break; case 'l': k |= 1 << 5; break;
		case 'u': k |= 1 << 6; break; case 'd': k |= 1 << 7; break;
	}
	return k;
}

static void (*vchk_store8)(struct SM83Core*, uint16_t, int8_t);
static struct GB* vchk_gb;
static unsigned vchk_n; static long frame_no;
static void vchk_store(struct SM83Core* cpu, uint16_t a, int8_t v) {
	struct GB* gb = vchk_gb;
	if (gb->memory.io[0x40] & 0x80) {
		int m = gb->video.mode;
		if ((a >= 0x8000 && a < 0xA000 && m == 3) || (a >= 0xFE00 && a < 0xFEA0 && (m == 2 || m == 3))) {
			if (vchk_n < 20) {
				unsigned sp = cpu->sp, r1 = cpu->memory.load8(cpu, sp) | cpu->memory.load8(cpu, sp + 1) << 8,
				         r2 = cpu->memory.load8(cpu, sp + 2) | cpu->memory.load8(cpu, sp + 3) << 8;
				fprintf(stderr, "VCHK %02X:%04X wr %04X mode %d LY %d frame %ld (stack %04X %04X)\n",
				        cpu->pc < 0x4000 ? 0 : gb->memory.currentBank, cpu->pc, a, m, gb->memory.io[0x44], frame_no, r1, r2);
			}
			vchk_n++;
		}
	}
	vchk_store8(cpu, a, v);
}

int main(int argc, char** argv) {
	if (argc < 2) { fprintf(stderr, "usage: mgsh ROM [--dmg|--cgb|--model M]\n"); return 2; }
	const char* model = "SGB"; int border = 1;
	for (int i = 2; i < argc; i++) {
		if (!strcmp(argv[i], "--dmg")) { model = "DMG"; border = 0; }
		else if (!strcmp(argv[i], "--cgb")) { model = "CGB"; border = 0; }
		else if (!strcmp(argv[i], "--model") && i + 1 < argc) { model = argv[++i]; border = 0; }
	}
	struct mCore* core = mCoreFind(argv[1]);
	if (!core || !core->init(core)) { fprintf(stderr, "no core\n"); return 1; }
	mCoreInitConfig(core, NULL);
	mCoreConfigSetValue(&core->config, "gb.model", model);
	mCoreConfigSetValue(&core->config, "sgb.model", model);
	mCoreConfigSetValue(&core->config, "cgb.model", model);
	mCoreConfigSetValue(&core->config, "cgb.hybridModel", model);
	mCoreConfigSetValue(&core->config, "cgb.sgbModel", model);
	mCoreConfigSetIntValue(&core->config, "sgb.borders", border);
	mCoreConfigSetIntValue(&core->config, "useBios", 0);
	mCoreLoadConfig(core);
	unsigned W = 256, H = 224, w, h;
	color_t* buf = calloc(W * H, sizeof(color_t));
	core->setVideoBuffer(core, buf, W);
	if (!mCoreLoadFile(core, argv[1])) { fprintf(stderr, "cannot load\n"); return 1; }
	core->reset(core);
	vchk_gb = (struct GB*) core->board;
	vchk_store8 = vchk_gb->cpu->memory.store8;
	vchk_gb->cpu->memory.store8 = vchk_store;
	char line[512];
	setvbuf(stdout, NULL, _IOLBF, 0);
	while (fgets(line, sizeof line, stdin)) {
		char cmd[8] = {0}, a1[400] = {0}, a2[64] = {0};
		int n = sscanf(line, "%7s %399s %63s", cmd, a1, a2);
		if (n < 1) continue;
		if (!strcmp(cmd, "f")) {
			int k = atoi(a1); unsigned keys = n > 2 && a2[0] != '-' ? parse_keys(a2) : 0;
			for (int i = 0; i < k; i++) { core->setKeys(core, keys); core->runFrame(core); frame_no++; }
			printf("ok %ld\n", frame_no);
		} else if (!strcmp(cmd, "r")) {
			unsigned ad = strtoul(a1, 0, 16); int cnt = n > 2 ? atoi(a2) : 1;
			for (int i = 0; i < cnt; i++) printf("%02X", core->busRead8(core, (ad + i) & 0xFFFF));
			printf("\n");
		} else if (!strcmp(cmd, "s")) {
			core->desiredVideoDimensions(core, &w, &h);
			FILE* f = fopen(a1, "wb");
			if (f) {
				fprintf(f, "P6\n%u %u\n255\n", w, h);
				for (unsigned y = 0; y < h; y++) for (unsigned x = 0; x < w; x++) {
					uint32_t c = buf[y * W + x];
					unsigned char px[3] = { c & 0xFF, (c >> 8) & 0xFF, (c >> 16) & 0xFF };
					fwrite(px, 1, 3, f);
				}
				fclose(f);
			}
			printf("ok\n");
		} else if (!strcmp(cmd, "p")) {             /* p ADDR VAL: poke a byte (hex) */
			core->busWrite8(core, strtoul(a1, 0, 16) & 0xFFFF, strtoul(a2, 0, 16) & 0xFF);
			printf("ok\n");
		} else if (!strcmp(cmd, "S") || !strcmp(cmd, "L")) {   /* state save / load */
			struct VFile* vf = VFileOpen(a1, cmd[0] == 'S' ? O_CREAT | O_TRUNC | O_WRONLY : O_RDONLY);
			int ok = 0;
			if (vf) { ok = cmd[0] == 'S' ? mCoreSaveStateNamed(core, vf, SAVESTATE_ALL) : mCoreLoadStateNamed(core, vf, SAVESTATE_ALL); vf->close(vf); }
			printf("ok %d\n", ok);
		} else if (!strcmp(cmd, "v")) {
			printf("%u\n", vchk_n);
		} else if (!strcmp(cmd, "q")) break;
		else printf("?\n");
	}
	core->deinit(core);
	return 0;
}
