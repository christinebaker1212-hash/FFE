/* Headless mGBA runner for SGB testing of the GB builds (palettes, border, packets).
 *
 * usage: sgbrun ROM FRAMES OUTPREFIX [--dmg] [--press KEYS@FRAME+HOLD ...] [--shot FRAME ...]
 *        [--padfile FILE] [--nshot K ...]
 *   --padfile: one NES pad byte per NES frame (bit 0 right .. 7 A, as the NES latched it),
 *     applied while the runtime's NES frame count ($D830) is that frame (as firstdiff.py);
 *   --nshot K: screenshot when the NES frame count first reaches K;
 *   --sram FILE: initial cart RAM (e.g. the NES power-on save RAM in bank 0, as compare.sync_sram).
 *   KEYS: letters a b s(elect) t(start) u d l r, e.g. --press t@700+5
 *   Screenshots: OUTPREFIX_fNNNNN.ppm (256x224 with the SGB border, 160x144 with --dmg).
 * Build: gcc -O2 sgbrun.c -lmgba -o sgbrun   (Ubuntu: apt install libmgba-dev)
 */
#include <mgba/core/core.h>
#include <mgba/core/config.h>
#include <mgba-util/vfs.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct press { int frame, hold; unsigned keys; };

static unsigned parse_keys(const char* s) {
	unsigned k = 0;
	for (; *s && *s != '@'; s++) switch (*s) {
		case 'a': k |= 1 << 0; break; case 'b': k |= 1 << 1; break;
		case 's': k |= 1 << 2; break; case 't': k |= 1 << 3; break;
		case 'r': k |= 1 << 4; break; case 'l': k |= 1 << 5; break;
		case 'u': k |= 1 << 6; break; case 'd': k |= 1 << 7; break;
	}
	return k;
}

static void save_ppm(const char* path, const color_t* buf, unsigned w, unsigned h, unsigned stride) {
	FILE* f = fopen(path, "wb");
	if (!f) return;
	fprintf(f, "P6\n%u %u\n255\n", w, h);
	for (unsigned y = 0; y < h; y++) for (unsigned x = 0; x < w; x++) {
		uint32_t c = buf[y * stride + x];
		unsigned char px[3] = { c & 0xFF, (c >> 8) & 0xFF, (c >> 16) & 0xFF };
		fwrite(px, 1, 3, f);
	}
	fclose(f);
}

int main(int argc, char** argv) {
	if (argc < 4) { fprintf(stderr, "usage: sgbrun ROM FRAMES OUTPREFIX [--dmg] [--press K@F+H] [--shot F]\n"); return 2; }
	int frames = atoi(argv[2]); const char* out = argv[3];
	int dmg = 0; struct press presses[256]; int np = 0; int shots[1024]; int ns = 0;
	const char* sram_path = NULL;
	unsigned char* pads = NULL; long npads = 0; int nshots[1024]; int nns = 0; int nshot_done[1024] = {0};
	for (int i = 4; i < argc; i++) {
		if (!strcmp(argv[i], "--dmg")) dmg = 1;
		else if (!strcmp(argv[i], "--cgb")) dmg = 2;
		else if (!strcmp(argv[i], "--press") && i + 1 < argc && np < 256) {
			const char* s = argv[++i]; const char* at = strchr(s, '@');
			presses[np].keys = parse_keys(s);
			presses[np].frame = at ? atoi(at + 1) : 0;
			const char* plus = at ? strchr(at, '+') : NULL;
			presses[np].hold = plus ? atoi(plus + 1) : 5;
			np++;
		} else if (!strcmp(argv[i], "--shot") && i + 1 < argc && ns < 1024) shots[ns++] = atoi(argv[++i]);
		else if (!strcmp(argv[i], "--nshot") && i + 1 < argc && nns < 1024) nshots[nns++] = atoi(argv[++i]);
		else if (!strcmp(argv[i], "--sram") && i + 1 < argc) sram_path = argv[++i];
		else if (!strcmp(argv[i], "--padfile") && i + 1 < argc) {
			FILE* pf = fopen(argv[++i], "rb");
			if (!pf) { fprintf(stderr, "no padfile\n"); return 1; }
			fseek(pf, 0, SEEK_END); npads = ftell(pf); fseek(pf, 0, SEEK_SET);
			pads = malloc(npads); if (fread(pads, 1, npads, pf) != (size_t) npads) return 1; fclose(pf);
		}
	}
	struct mCore* core = mCoreFind(argv[1]);
	if (!core || !core->init(core)) { fprintf(stderr, "no core for %s\n", argv[1]); return 1; }
	mCoreInitConfig(core, NULL);
	/* the model for every kind of cart header (a dual-mode cart would otherwise run as CGB) */
	const char* model = dmg == 2 ? "CGB" : dmg ? "DMG" : "SGB";
	mCoreConfigSetValue(&core->config, "gb.model", model);
	mCoreConfigSetValue(&core->config, "sgb.model", model);
	mCoreConfigSetValue(&core->config, "cgb.model", model);
	mCoreConfigSetValue(&core->config, "cgb.hybridModel", model);
	mCoreConfigSetValue(&core->config, "cgb.sgbModel", model);
	mCoreConfigSetIntValue(&core->config, "sgb.borders", dmg ? 0 : 1);   /* --cgb: Game Boy Color */
	mCoreConfigSetIntValue(&core->config, "useBios", 0);
	mCoreLoadConfig(core);
	unsigned w, h;
	core->desiredVideoDimensions(core, &w, &h);
	unsigned W = 256, H = 224;                       /* allocate for the largest (SGB border) */
	color_t* buf = calloc(W * H, sizeof(color_t));
	core->setVideoBuffer(core, buf, W);
	if (!mCoreLoadFile(core, argv[1])) { fprintf(stderr, "cannot load %s\n", argv[1]); return 1; }
	core->reset(core);
	if (sram_path) {
		FILE* sf = fopen(sram_path, "rb");
		if (!sf) { fprintf(stderr, "no sram file\n"); return 1; }
		static unsigned char sram[0x8000];
		size_t n = fread(sram, 1, sizeof sram, sf); fclose(sf);
		core->savedataRestore(core, sram, n, false);
	}
	char path[1024];
	for (int f = 1; f <= frames; f++) {
		unsigned keys = 0;
		for (int k = 0; k < np; k++)
			if (f >= presses[k].frame && f < presses[k].frame + presses[k].hold) keys |= presses[k].keys;
		if (pads) {
			unsigned n = core->rawRead8(core, 0xD830, 1) | core->rawRead8(core, 0xD831, 1) << 8;
			unsigned char m = n + 1 < npads ? pads[n + 1] : 0;   /* the pad of the frame being played */
			static const unsigned map[8] = { 1 << 4, 1 << 5, 1 << 7, 1 << 6, 1 << 3, 1 << 2, 1 << 1, 1 << 0 };
			for (int b = 0; b < 8; b++) if (m & (1 << b)) keys |= map[b];
		}
		core->setKeys(core, keys);
		core->runFrame(core);
		int shot = (f == frames);
		for (int k = 0; k < ns; k++) if (shots[k] == f) shot = 1;
		if (nns) {
			unsigned n = core->rawRead8(core, 0xD830, 1) | core->rawRead8(core, 0xD831, 1) << 8;
			for (int k = 0; k < nns; k++) if (!nshot_done[k] && n >= (unsigned) nshots[k]) {
				nshot_done[k] = 1;
				core->desiredVideoDimensions(core, &w, &h);
				snprintf(path, sizeof path, "%s_n%05d.ppm", out, nshots[k]);
				if (getenv("SGBRUN_RAM")) {                 /* NES RAM ($C000-$C7FF) */
					char rp[1100]; snprintf(rp, sizeof rp, "%s_n%05d.ram", out, nshots[k]);
					FILE* rf = fopen(rp, "wb");
					for (unsigned a = 0xC000; a < 0xC800; a++) fputc(core->busRead8(core, a), rf);
					fclose(rf);
				}
				if (getenv("SGBRUN_SGB")) {                 /* HRAM and cart RAM bank 2 (SGB packets) */
					printf("nshot %d HRAM:", nshots[k]);
					for (unsigned a = 0xFF80; a < 0xFFFF; a++) printf(" %02X", core->busRead8(core, a));
					printf("\nRAM2:");
					for (unsigned a = 0; a < 0x100; a++) printf("%s%02X", a % 16 ? " " : "\n ", core->rawRead8(core, 0xA000 + a, 2));
					printf("\n");
				}
				if (getenv("SGBRUN_HD")) {                  /* CGB tile copy (WRAM 2) vs VRAM */
					int bad = 0;
					for (int t = 0; t < 256; t++) {
						unsigned v = t < 128 ? 0x9000 + t * 16 : 0x8800 + (t - 128) * 16;
						for (int i = 0; i < 16; i++)
							if (core->rawRead8(core, 0xD000 + t * 16 + i, 2) != core->rawRead8(core, v + i, 0)) {
								if (bad < 6) { printf("tile %02X stage", t); for (int j = 0; j < 16; j++) printf(" %02X", core->rawRead8(core, 0xD000 + t * 16 + j, 2));
									printf(" vram"); for (int j = 0; j < 16; j++) printf(" %02X", core->rawRead8(core, v + j, 0)); printf("\n"); }
								bad++; break; }
					}
					printf("nshot %d: tiles differing %d, dirty", nshots[k], bad);
					for (int i = 0; i < 32; i++) printf(" %02X", core->busRead8(core, 0xCCA0 + i));
					printf("\nring:"); for (int i = 0; i < 256; i++) printf(" %02X", core->rawRead8(core, 0xDE00 + i, 1));
					printf(" SVBK %02X VBK %02X dbg %02X %02X %02X\n", core->busRead8(core, 0xFF70), core->busRead8(core, 0xFF4F),
						core->busRead8(core, 0xCCD0), core->busRead8(core, 0xCCD1), core->busRead8(core, 0xCCD2));
				}
				if (getenv("SGBRUN_REGS"))
					printf("nshot %d: LCDC %02X STAT %02X SCY %02X SCX %02X LY %02X LYC %02X BGP %02X\n", nshots[k],
						core->busRead8(core, 0xFF40), core->busRead8(core, 0xFF41), core->busRead8(core, 0xFF42),
						core->busRead8(core, 0xFF43), core->busRead8(core, 0xFF44), core->busRead8(core, 0xFF45),
						core->busRead8(core, 0xFF47));
				save_ppm(path, buf, w, h, W);
			}
			int all = 1;
			for (int k = 0; k < nns; k++) all &= nshot_done[k];
			if (all) { frames = f; break; }
		}
		if (shot) {
			core->desiredVideoDimensions(core, &w, &h);
			snprintf(path, sizeof path, "%s_f%05d.ppm", out, f);
			save_ppm(path, buf, w, h, W);
		}
	}
	/* frame-wait counter of the runtime ($D830), to confirm the game ran */
	unsigned n = core->rawRead8(core, 0xD830, 1) | core->rawRead8(core, 0xD831, 1) << 8;
	printf("frames %d, video %ux%u, NES frame waits %u, KEY1 %02X\n", frames, w, h, n, core->busRead8(core, 0xFF4D));
	core->deinit(core);
	return 0;
}
