/* Headless mGBA runner for SGB testing of the GB builds (palettes, border, packets).
 *
 * usage: sgbrun ROM FRAMES OUTPREFIX [--dmg] [--press KEYS@FRAME+HOLD ...] [--shot FRAME ...]
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
	for (int i = 4; i < argc; i++) {
		if (!strcmp(argv[i], "--dmg")) dmg = 1;
		else if (!strcmp(argv[i], "--press") && i + 1 < argc && np < 256) {
			const char* s = argv[++i]; const char* at = strchr(s, '@');
			presses[np].keys = parse_keys(s);
			presses[np].frame = at ? atoi(at + 1) : 0;
			const char* plus = at ? strchr(at, '+') : NULL;
			presses[np].hold = plus ? atoi(plus + 1) : 5;
			np++;
		} else if (!strcmp(argv[i], "--shot") && i + 1 < argc && ns < 1024) shots[ns++] = atoi(argv[++i]);
	}
	struct mCore* core = mCoreFind(argv[1]);
	if (!core || !core->init(core)) { fprintf(stderr, "no core for %s\n", argv[1]); return 1; }
	mCoreInitConfig(core, NULL);
	mCoreConfigSetValue(&core->config, "gb.model", dmg ? "DMG" : "SGB");
	mCoreConfigSetIntValue(&core->config, "sgb.borders", dmg ? 0 : 1);
	mCoreConfigSetIntValue(&core->config, "useBios", 0);
	mCoreLoadConfig(core);
	unsigned w, h;
	core->desiredVideoDimensions(core, &w, &h);
	unsigned W = 256, H = 224;                       /* allocate for the largest (SGB border) */
	color_t* buf = calloc(W * H, sizeof(color_t));
	core->setVideoBuffer(core, buf, W);
	if (!mCoreLoadFile(core, argv[1])) { fprintf(stderr, "cannot load %s\n", argv[1]); return 1; }
	core->reset(core);
	char path[1024];
	for (int f = 1; f <= frames; f++) {
		unsigned keys = 0;
		for (int k = 0; k < np; k++)
			if (f >= presses[k].frame && f < presses[k].frame + presses[k].hold) keys |= presses[k].keys;
		core->setKeys(core, keys);
		core->runFrame(core);
		int shot = (f == frames);
		for (int k = 0; k < ns; k++) if (shots[k] == f) shot = 1;
		if (shot) {
			core->desiredVideoDimensions(core, &w, &h);
			snprintf(path, sizeof path, "%s_f%05d.ppm", out, f);
			save_ppm(path, buf, w, h, W);
		}
	}
	/* frame-wait counter of the runtime ($D830), to confirm the game ran */
	unsigned n = core->busRead8(core, 0xD830) | core->busRead8(core, 0xD831) << 8;
	printf("frames %d, video %ux%u, NES frame waits %u\n", frames, w, h, n);
	core->deinit(core);
	return 0;
}
