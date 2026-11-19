/* Headless runner for a GB ROM on the Gambatte libretro core (cycle-accurate, enforces
 * the hardware's VRAM / OAM / palette access windows): the closest stand-in for a real
 * Game Boy / Game Boy Color available here.
 * build: gcc -O2 -I/usr/include/libretro-common tools/gb/gambatte/gbrun.c -ldl -o build/gbrun
 *   (apt-get install libretro-gambatte retroarch-dev)
 * usage: gbrun ROM FRAMES OUTPREFIX [--dmg] [--padfile F] [--nshot K ...] [--sram F]
 *              [--wav FILE] [--wav-from K] [--poke K ADDR=VAL,..]
 *   --padfile: one NES pad byte per NES frame (bit 0 right .. 7 A, as the NES latched it),
 *     fed by the NES frame count the ROM keeps at $D830 (as tools/gb/mgba/sgbrun.c)
 *   --nshot K: screenshot (OUTPREFIX_nKKKKK.ppm) when the NES frame count reaches K; the
 *     run ends after the last one
 *   --wav FILE: the sound output (stereo 16-bit) from NES frame --wav-from on
 *   --poke: as sgbrun (NES $0000-$07FF = WRAM $C000.., $6000-$7FFF = cart RAM)
 *   --lagfile F: the NES frame count (16 bits) after every GB frame
 *   prints "frames N, NES frame waits M" at the end */
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libretro.h>

static const char* CORE = "/usr/lib/x86_64-linux-gnu/libretro/gambatte_libretro.so";
static int dmg = 0;
static unsigned keys = 0;
static int pixfmt = RETRO_PIXEL_FORMAT_0RGB1555;
static uint8_t frame[160 * 144 * 3];
static FILE* wav = NULL; static long wav_bytes = 0; static int wav_on = 0;

static bool env_cb(unsigned cmd, void* data) {
	switch (cmd) {
	case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: pixfmt = *(const enum retro_pixel_format*) data; return true;
	case RETRO_ENVIRONMENT_GET_VARIABLE: {
		struct retro_variable* v = data;
		if (!strcmp(v->key, "gambatte_gb_hwmode")) { v->value = dmg ? "GB" : "GBC"; return true; }
		if (!strcmp(v->key, "gambatte_gb_colorization")) { v->value = "disabled"; return true; }
		if (!strcmp(v->key, "gambatte_gb_internal_palette")) { v->value = "GB - DMG"; return true; }
		if (!strcmp(v->key, "sameboy_model")) { v->value = dmg ? "Game Boy" : "Game Boy Color"; return true; }
		v->value = NULL; return false;
	}
	case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
	case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY: *(const char**) data = "."; return true;
	case RETRO_ENVIRONMENT_GET_CAN_DUPE: *(bool*) data = true; return true;
	case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE: *(bool*) data = false; return true;
	default: return false;
	}
}

static void video_cb(const void* d, unsigned w, unsigned h, size_t pitch) {
	if (!d || w != 160 || h != 144) return;
	for (unsigned y = 0; y < h; y++)
		for (unsigned x = 0; x < w; x++) {
			uint8_t* o = frame + (y * 160 + x) * 3;
			if (pixfmt == RETRO_PIXEL_FORMAT_XRGB8888) {
				uint32_t p = ((const uint32_t*) ((const uint8_t*) d + y * pitch))[x];
				o[0] = p >> 16; o[1] = p >> 8; o[2] = p;
			} else if (pixfmt == RETRO_PIXEL_FORMAT_RGB565) {
				uint16_t p = ((const uint16_t*) ((const uint8_t*) d + y * pitch))[x];
				o[0] = (p >> 11) << 3; o[1] = ((p >> 5) & 63) << 2; o[2] = (p & 31) << 3;
			} else {
				uint16_t p = ((const uint16_t*) ((const uint8_t*) d + y * pitch))[x];
				o[0] = ((p >> 10) & 31) << 3; o[1] = ((p >> 5) & 31) << 3; o[2] = (p & 31) << 3;
			}
		}
}

static void audio_cb(int16_t l, int16_t r) {
	if (wav && wav_on) { int16_t s[2] = { l, r }; fwrite(s, 2, 2, wav); wav_bytes += 4; }
}
static size_t audio_batch_cb(const int16_t* d, size_t n) {
	if (wav && wav_on) { fwrite(d, 4, n, wav); wav_bytes += 4 * n; }
	return n;
}
static void poll_cb(void) {}
static int16_t input_cb(unsigned port, unsigned dev, unsigned idx, unsigned id) {
	if (port || dev != RETRO_DEVICE_JOYPAD) return 0;
	if (id == RETRO_DEVICE_ID_JOYPAD_MASK) return keys;
	return (keys >> id) & 1;
}

static void wav_header(FILE* f, long bytes, int rate) {
	uint32_t v; uint16_t s;
	fseek(f, 0, SEEK_SET);
	fwrite("RIFF", 1, 4, f); v = 36 + bytes; fwrite(&v, 4, 1, f); fwrite("WAVEfmt ", 1, 8, f);
	v = 16; fwrite(&v, 4, 1, f); s = 1; fwrite(&s, 2, 1, f); s = 2; fwrite(&s, 2, 1, f);
	v = rate; fwrite(&v, 4, 1, f); v = rate * 4; fwrite(&v, 4, 1, f); s = 4; fwrite(&s, 2, 1, f);
	s = 16; fwrite(&s, 2, 1, f); fwrite("data", 1, 4, f); v = bytes; fwrite(&v, 4, 1, f);
}

int main(int argc, char** argv) {
	if (argc < 4) { fprintf(stderr, "usage: gbrun ROM FRAMES OUT [options]\n"); return 2; }
	int frames = atoi(argv[2]); const char* out = argv[3];
	const char* padfile = NULL; const char* sram_path = NULL; const char* wav_path = NULL;
	int nshots[1024]; int nns = 0; int done[1024] = { 0 }; int wav_from = 0;
	int poke_at = 0; const char* poke_list = NULL; FILE* lagf = NULL; int until = 0;
	for (int i = 4; i < argc; i++) {
		if (!strcmp(argv[i], "--dmg")) dmg = 1;
		else if (!strcmp(argv[i], "--padfile") && i + 1 < argc) padfile = argv[++i];
		else if (!strcmp(argv[i], "--nshot") && i + 1 < argc && nns < 1024) nshots[nns++] = atoi(argv[++i]);
		else if (!strcmp(argv[i], "--sram") && i + 1 < argc) sram_path = argv[++i];
		else if (!strcmp(argv[i], "--wav") && i + 1 < argc) wav_path = argv[++i];
		else if (!strcmp(argv[i], "--wav-from") && i + 1 < argc) wav_from = atoi(argv[++i]);
		else if (!strcmp(argv[i], "--poke") && i + 2 < argc) { poke_at = atoi(argv[++i]); poke_list = argv[++i]; }
		else if (!strcmp(argv[i], "--lagfile") && i + 1 < argc) lagf = fopen(argv[++i], "wb");
		else if (!strcmp(argv[i], "--until") && i + 1 < argc) until = atoi(argv[++i]);
	}
	unsigned char* pads = NULL; long npads = 0;
	if (padfile) {
		FILE* pf = fopen(padfile, "rb"); if (!pf) { perror(padfile); return 1; }
		fseek(pf, 0, SEEK_END); npads = ftell(pf); fseek(pf, 0, SEEK_SET);
		pads = malloc(npads); if (fread(pads, 1, npads, pf) != (size_t) npads) return 1; fclose(pf);
	}
	if (getenv("GBRUN_CORE")) CORE = getenv("GBRUN_CORE");   /* e.g. SameBoy's libretro core */
	void* h = dlopen(CORE, RTLD_NOW); if (!h) { fprintf(stderr, "%s\n", dlerror()); return 1; }
#define SYM(n) typeof(&n) p_##n = (typeof(&n)) dlsym(h, #n)
	SYM(retro_set_environment); SYM(retro_set_video_refresh); SYM(retro_set_audio_sample);
	SYM(retro_set_audio_sample_batch); SYM(retro_set_input_poll); SYM(retro_set_input_state);
	SYM(retro_init); SYM(retro_load_game); SYM(retro_run); SYM(retro_get_memory_data);
	SYM(retro_get_memory_size); SYM(retro_get_system_av_info); SYM(retro_deinit); SYM(retro_reset);
	p_retro_set_environment(env_cb); p_retro_init();
	p_retro_set_video_refresh(video_cb); p_retro_set_audio_sample(audio_cb);
	p_retro_set_audio_sample_batch(audio_batch_cb); p_retro_set_input_poll(poll_cb);
	p_retro_set_input_state(input_cb);
	FILE* rf = fopen(argv[1], "rb"); if (!rf) { perror(argv[1]); return 1; }
	fseek(rf, 0, SEEK_END); long rsize = ftell(rf); fseek(rf, 0, SEEK_SET);
	void* rom = malloc(rsize); if (fread(rom, 1, rsize, rf) != (size_t) rsize) return 1; fclose(rf);
	struct retro_game_info gi = { argv[1], rom, (size_t) rsize, NULL };
	if (!p_retro_load_game(&gi)) { fprintf(stderr, "load failed\n"); return 1; }
	if (sram_path) {
		uint8_t* s = p_retro_get_memory_data(RETRO_MEMORY_SAVE_RAM);
		size_t n = p_retro_get_memory_size(RETRO_MEMORY_SAVE_RAM);
		FILE* sf = fopen(sram_path, "rb");
		if (s && sf) { size_t r = fread(s, 1, n, sf); (void) r; }
		if (sf) fclose(sf);
		p_retro_reset();
	}
	struct retro_system_av_info av; p_retro_get_system_av_info(&av);
	int rate = (int) (av.timing.sample_rate + 0.5);
	if (wav_path) { wav = fopen(wav_path, "wb"); wav_header(wav, 0, rate); }
	uint8_t* wram = p_retro_get_memory_data(RETRO_MEMORY_SYSTEM_RAM);
	size_t wsize = p_retro_get_memory_size(RETRO_MEMORY_SYSTEM_RAM);
	if (!wram || wsize < 0x2000) { fprintf(stderr, "no system RAM\n"); return 1; }
	memset(wram, 0, wsize);      /* (cores with a boot ROM, e.g. SameBoy: no random frame counter) */
	/* $D830 lives in WRAM bank 1 (offset $1830 both on DMG and on CGB) */
#define NESF() (wram[0x1830] | wram[0x1831] << 8)
	static const unsigned map[8] = { RETRO_DEVICE_ID_JOYPAD_RIGHT, RETRO_DEVICE_ID_JOYPAD_LEFT,
		RETRO_DEVICE_ID_JOYPAD_DOWN, RETRO_DEVICE_ID_JOYPAD_UP, RETRO_DEVICE_ID_JOYPAD_START,
		RETRO_DEVICE_ID_JOYPAD_SELECT, RETRO_DEVICE_ID_JOYPAD_B, RETRO_DEVICE_ID_JOYPAD_A };
	int f;
	for (f = 1; f <= frames; f++) {
		unsigned n = NESF();
		if (poke_list && f > 30 && n >= (unsigned) poke_at) {
			uint8_t* sram = p_retro_get_memory_data(RETRO_MEMORY_SAVE_RAM);
			for (const char* p = poke_list; *p;) {
				unsigned a, v; int used;
				if (sscanf(p, "%x=%x%n", &a, &v, &used) != 2) break;
				if (a < 0x800) wram[a] = v;
				else if (a >= 0x6000 && a < 0x8000 && sram) sram[a - 0x6000] = v;
				p += used; if (*p == ',') p++;
			}
			poke_list = NULL;
		}
		keys = 0;
		if (pads) {
			unsigned char m = (f > 30 && n + 1 < (unsigned) npads) ? pads[n + 1] : 0;
			for (int b = 0; b < 8; b++) if (m & (1 << b)) keys |= 1u << map[b];
			/* exact input: the ROM's test mode (TEST_PAD $D83E = $A5) reads the pad of the
			   frame after wait k from cart RAM bank 3 $A000 + (k & $FF), in its button order
			   (A B Sel St U D L R = bit 0..7: the NES order reversed) */
			uint8_t* sr = p_retro_get_memory_data(RETRO_MEMORY_SAVE_RAM);
			if (f > 30 && sr && p_retro_get_memory_size(RETRO_MEMORY_SAVE_RAM) >= 0x8000) {
				wram[0x183E] = 0xA5;
				for (unsigned k = n; k < n + 32; k++) {
					unsigned char v = k + 1 < (unsigned) npads ? pads[k + 1] : 0, r = 0;
					for (int b = 0; b < 8; b++) if (v & (1 << b)) r |= 0x80 >> b;
					sr[0x6000 + (k & 0xFF)] = r;
				}
			}
		}
		wav_on = (int) n >= wav_from;
		p_retro_run();
		n = NESF();
		if (lagf) { uint16_t v = f > 30 ? n : 0; fwrite(&v, 2, 1, lagf); }
		if (until && f > 30 && n >= (unsigned) until) break;
		int all = nns > 0;
		for (int k = 0; k < nns; k++) {
			if (!done[k] && f > 30 && n >= (unsigned) nshots[k]) {  /* (DMG WRAM is random before boot clears it) */
				done[k] = 1; printf("shot %d at GB frame %d\n", nshots[k], f);
				char path[1100]; snprintf(path, sizeof path, "%s_n%05d.ppm", out, nshots[k]);
				FILE* o = fopen(path, "wb"); fprintf(o, "P6 160 144 255\n"); fwrite(frame, 1, sizeof frame, o); fclose(o);
				snprintf(path, sizeof path, "%s_n%05d.ram", out, nshots[k]);   /* NES RAM $0000-$07FF */
				o = fopen(path, "wb"); fwrite(wram, 1, 0x800, o); fclose(o);
				if (getenv("GBRUN_DBG")) {   /* (debug ring $DE00-$DEFF) */
					snprintf(path, sizeof path, "%s_n%05d.dbg", out, nshots[k]);
					o = fopen(path, "wb"); fwrite(wram + 0x1E00, 1, 0x100, o); fclose(o);
				}
			}
			all &= done[k];
		}
		if (all) break;
	}
	if (wav) { wav_header(wav, wav_bytes, rate); fclose(wav); }
	if (lagf) fclose(lagf);
	printf("frames %d, NES frame waits %u, rate %d\n", f, NESF(), rate);
	if (getenv("GBRUN_DBG")) {   /* the runtime's fault record DBG ($D820) and a few flags */
		printf("DBG"); for (int i = 0; i < 16; i++) printf(" %02X", wram[0x1820 + i]); printf("\n");
		printf("ISR_PC %02X%02X\n", wram[0x1877], wram[0x1876]);
		printf("DDFF %02X\n", wram[0x1DFF]);
	}
	p_retro_deinit();
	return 0;
}
