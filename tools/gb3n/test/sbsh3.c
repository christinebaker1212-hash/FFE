/* FF3's copy of tools/gb/sameboy/sbsh.c (FF1's tool, unchanged there) with work RAM access by
 * bank, for the FF3 core rewrite's checks (docs/ff3-gb-rewrite.md): NES RAM lives in GB $C000-$CFFF
 * and work RAM bank 1, which the core's bus map does not give back reliably.
 *   R BANK ADDR N   read N bytes of work RAM: $C000-$CFFF bank 0, $D000-$DFFF bank BANK (hex)
 *   P BANK ADDR HEX write the bytes HEX (e.g. 01FF3A) there                -> "ok"
 * build: gcc -O2 -I/usr/include/libretro-common tools/gb3n/test/sbsh3.c -ldl -o build/sbsh3
 *
 * Interactive headless runner on a libretro Game Boy core (SameBoy by default: the most
 * hardware-accurate core available here; Gambatte with SBSH_CORE). Same protocol as
 * tools/gb/mgba/mgsh.c, so test scripts can switch emulators.
 *
 * usage: sbsh ROM [--model VALUE]   (SameBoy's sameboy_model value, e.g. "Game Boy",
 *        "Game Boy Color", "Game Boy Color D", "Game Boy Advance", "Super Game Boy";
 *        default "Game Boy Color")
 * commands (one a line), each answered with one line:
 *   f N KEYS      run N frames holding KEYS (a b s t u d l r, or -)   -> "ok FRAME"
 *   r ADDR N      read N bytes through the core's memory map (hex)    -> hex bytes
 *   s PATH        screenshot (PPM 160x144)                            -> "ok"
 *   w PATH        start recording the sound (WAV 48 kHz stereo 16-bit) -> "ok CORE_RATE"
 *   W             stop recording                                       -> "ok"
 *   S PATH / L PATH  save / load a state                               -> "ok" / "err"
 *   c OFF N       read N bytes of the cartridge RAM (battery RAM, all banks: bank x $2000
 *                 + offset) (hex)                                      -> hex bytes
 *   v             VRAM/OAM checker: CPU writes the hardware dropped (VRAM in mode 3, OAM in
 *                 modes 2-3) since boot, from a core patched to export GB_vchk_n (docs/gb-lessons.md
 *                 "Testing"); 0 with a core without it
 *   q             quit
 * F N KEYS: as f, printing each frame's count of dark pixels (finds black screens)
 * build: gcc -O2 -I/usr/include/libretro-common tools/gb/sameboy/sbsh.c -ldl -o build/sbsh
 * core:  build/sameboy_libretro.so (see docs/gb-lessons.md), env SBSH_CORE overrides */
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libretro.h>

static const char* model = "Game Boy Color";
static unsigned keys = 0;
static int pixfmt = RETRO_PIXEL_FORMAT_0RGB1555;
static uint8_t frame[160 * 144 * 3];
static FILE* wav = NULL; static long wav_bytes = 0; static int rate = 0;
static struct retro_memory_descriptor maps[64]; static unsigned nmaps = 0;

static bool env_cb(unsigned cmd, void* data) {
	switch (cmd) {
	case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: pixfmt = *(const enum retro_pixel_format*) data; return true;
	case RETRO_ENVIRONMENT_GET_VARIABLE: {
		struct retro_variable* v = data;
		if (!strncmp(v->key, "sameboy_model", 13)) { v->value = model; return true; }
		if (!strcmp(v->key, "sameboy_high_pass_filter_mode")) { v->value = "accurate"; return true; }
		if (!strcmp(v->key, "sameboy_border")) { v->value = "never"; return true; }
		if (!strcmp(v->key, "sameboy_color_correction_mode") && getenv("SB_CC")) { v->value = getenv("SB_CC"); return true; }   /* SB_CC=off: raw RGB555 colours */
		if (!strcmp(v->key, "gambatte_gb_hwmode")) { v->value = strstr(model, "Color") ? "GBC" : "GB"; return true; }
		if (!strcmp(v->key, "gambatte_gb_colorization")) { v->value = "disabled"; return true; }
		v->value = NULL; return false;
	}
	case RETRO_ENVIRONMENT_SET_MEMORY_MAPS: {
		const struct retro_memory_map* m = data;
		for (unsigned i = 0; i < m->num_descriptors && nmaps < 64; i++) maps[nmaps++] = m->descriptors[i];
		return true;
	}
	case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
	case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY: *(const char**) data = "."; return true;
	case RETRO_ENVIRONMENT_GET_CAN_DUPE: *(bool*) data = true; return true;
	case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE: *(bool*) data = false; return true;
	default: return false;
	}
}

static void video_cb(const void* d, unsigned w, unsigned h, size_t pitch) {
	if (!d || w < 160 || h < 144) return;
	unsigned ox = (w - 160) / 2, oy = (h - 144) / 2;
	for (unsigned y = 0; y < 144; y++)
		for (unsigned x = 0; x < 160; x++) {
			uint8_t* o = frame + (y * 160 + x) * 3;
			const uint8_t* row = (const uint8_t*) d + (y + oy) * pitch;
			if (pixfmt == RETRO_PIXEL_FORMAT_XRGB8888) {
				uint32_t p = ((const uint32_t*) row)[x + ox];
				o[0] = p >> 16; o[1] = p >> 8; o[2] = p;
			} else if (pixfmt == RETRO_PIXEL_FORMAT_RGB565) {
				uint16_t p = ((const uint16_t*) row)[x + ox];
				o[0] = (p >> 11) << 3; o[1] = ((p >> 5) & 63) << 2; o[2] = (p & 31) << 3;
			} else {
				uint16_t p = ((const uint16_t*) row)[x + ox];
				o[0] = ((p >> 10) & 31) << 3; o[1] = ((p >> 5) & 31) << 3; o[2] = (p & 31) << 3;
			}
		}
}
/* the core's rate (SameBoy: ~2 MHz) box-filtered down to 48 kHz */
static double acc_l, acc_r, acc_n, acc_t;
static void audio_cb(int16_t l, int16_t r) {
	if (!wav) return;
	acc_l += l; acc_r += r; acc_n++; acc_t += 48000.0;
	if (acc_t >= rate) {
		acc_t -= rate; int16_t s[2] = { (int16_t) (acc_l / acc_n), (int16_t) (acc_r / acc_n) };
		fwrite(s, 2, 2, wav); wav_bytes += 4; acc_l = acc_r = acc_n = 0;
	}
}
static size_t audio_batch_cb(const int16_t* d, size_t n) { for (size_t i = 0; i < n; i++) audio_cb(d[2 * i], d[2 * i + 1]); return n; }
static void poll_cb(void) {}
static int16_t input_cb(unsigned port, unsigned dev, unsigned idx, unsigned id) {
	if (port || dev != RETRO_DEVICE_JOYPAD) return 0;
	if (id == RETRO_DEVICE_ID_JOYPAD_MASK) return keys;
	return (keys >> id) & 1;
}
static void wav_header(FILE* f, long bytes) {
	uint32_t v; uint16_t s;
	fseek(f, 0, SEEK_SET);
	fwrite("RIFF", 1, 4, f); v = 36 + bytes; fwrite(&v, 4, 1, f); fwrite("WAVEfmt ", 1, 8, f);
	v = 16; fwrite(&v, 4, 1, f); s = 1; fwrite(&s, 2, 1, f); s = 2; fwrite(&s, 2, 1, f);
	v = 48000; fwrite(&v, 4, 1, f); v = 48000 * 4; fwrite(&v, 4, 1, f); s = 4; fwrite(&s, 2, 1, f);
	s = 16; fwrite(&s, 2, 1, f); fwrite("data", 1, 4, f); v = bytes; fwrite(&v, 4, 1, f);
	fseek(f, 0, SEEK_END);
}
static unsigned parse_keys(const char* s) {   /* libretro joypad ids */
	unsigned k = 0;
	for (; *s; s++) switch (*s) {
		case 'a': k |= 1 << RETRO_DEVICE_ID_JOYPAD_A; break; case 'b': k |= 1 << RETRO_DEVICE_ID_JOYPAD_B; break;
		case 's': k |= 1 << RETRO_DEVICE_ID_JOYPAD_SELECT; break; case 't': k |= 1 << RETRO_DEVICE_ID_JOYPAD_START; break;
		case 'r': k |= 1 << RETRO_DEVICE_ID_JOYPAD_RIGHT; break; case 'l': k |= 1 << RETRO_DEVICE_ID_JOYPAD_LEFT; break;
		case 'u': k |= 1 << RETRO_DEVICE_ID_JOYPAD_UP; break; case 'd': k |= 1 << RETRO_DEVICE_ID_JOYPAD_DOWN; break;
	}
	return k;
}
static int poke = -1;
static int rd(unsigned a, uint8_t* out) {
	for (unsigned i = 0; i < nmaps; i++) {
		struct retro_memory_descriptor* m = &maps[i];
		if (!m->ptr || !m->len) continue;
		size_t sel = m->select ? m->select : (~(size_t) 0 << 16 | ~(m->len - 1)) ;
		if (m->select == 0) { if (a < m->start || a >= m->start + m->len) continue; }
		else if ((a & m->select) != (m->start & m->select)) continue;
		(void) sel;
		size_t off = a - m->start; if (m->len) off %= m->len;
		if (poke >= 0) ((uint8_t*) m->ptr)[m->offset + off] = (uint8_t) poke;
		*out = ((uint8_t*) m->ptr)[m->offset + off];
		return 1;
	}
	return 0;
}

int main(int argc, char** argv) {
	if (argc < 2) { fprintf(stderr, "usage: sbsh ROM [--model M]\n"); return 2; }
	for (int i = 2; i < argc; i++) if (!strcmp(argv[i], "--model") && i + 1 < argc) model = argv[++i];
	const char* core = getenv("SBSH_CORE") ? getenv("SBSH_CORE") : "build/sameboy_libretro.so";
	void* h = dlopen(core, RTLD_NOW); if (!h) { fprintf(stderr, "%s\n", dlerror()); return 1; }
#define SYM(n) typeof(&n) p_##n = (typeof(&n)) dlsym(h, #n)
	SYM(retro_set_environment); SYM(retro_set_video_refresh); SYM(retro_set_audio_sample);
	SYM(retro_set_audio_sample_batch); SYM(retro_set_input_poll); SYM(retro_set_input_state);
	SYM(retro_init); SYM(retro_load_game); SYM(retro_run); SYM(retro_get_system_av_info);
	SYM(retro_serialize_size); SYM(retro_serialize); SYM(retro_unserialize);
	SYM(retro_get_memory_data); SYM(retro_get_memory_size);
	p_retro_set_environment(env_cb); p_retro_init();
	p_retro_set_video_refresh(video_cb); p_retro_set_audio_sample(audio_cb);
	p_retro_set_audio_sample_batch(audio_batch_cb); p_retro_set_input_poll(poll_cb);
	p_retro_set_input_state(input_cb);
	unsigned* vchk_n = (unsigned*) dlsym(h, "GB_vchk_n");   /* (patched SameBoy core only) */
	FILE* rf = fopen(argv[1], "rb"); if (!rf) { perror(argv[1]); return 1; }
	fseek(rf, 0, SEEK_END); long rsize = ftell(rf); fseek(rf, 0, SEEK_SET);
	void* rom = malloc(rsize); if (fread(rom, 1, rsize, rf) != (size_t) rsize) return 1; fclose(rf);
	struct retro_game_info gi = { argv[1], rom, (size_t) rsize, NULL };
	if (!p_retro_load_game(&gi)) { fprintf(stderr, "load failed\n"); return 1; }
	struct retro_system_av_info av; p_retro_get_system_av_info(&av);
	rate = (int) (av.timing.sample_rate + 0.5);
	long frame_no = 0; char line[4096];
	setvbuf(stdout, NULL, _IOLBF, 0);
	while (fgets(line, sizeof line, stdin)) {
		char cmd[8] = {0}, a1[400] = {0}, a2[64] = {0};
		int n = sscanf(line, "%7s %399s %63s", cmd, a1, a2);
		if (n < 1) continue;
		if (!strcmp(cmd, "f")) {
			int k = atoi(a1); keys = n > 2 && a2[0] != '-' ? parse_keys(a2) : 0;
			for (int i = 0; i < k; i++) { p_retro_run(); frame_no++; }
			keys = 0;
			printf("ok %ld\n", frame_no);
		} else if (!strcmp(cmd, "F")) {             /* F N KEYS: N frames, each frame's dark pixel count (sum < 150) */
			int k = atoi(a1); keys = n > 2 && a2[0] != '-' ? parse_keys(a2) : 0;
			for (int i = 0; i < k; i++) {
				p_retro_run(); frame_no++;
				int d = 0; for (int j = 0; j < 160 * 144; j++) d += frame[j * 3] + frame[j * 3 + 1] + frame[j * 3 + 2] < 150;
				printf(i ? ",%d" : "%d", d);
			}
			keys = 0;
			printf("\n");
		} else if (!strcmp(cmd, "r")) {
			unsigned ad = strtoul(a1, 0, 16); int cnt = n > 2 ? atoi(a2) : 1;
			for (int i = 0; i < cnt; i++) { uint8_t b = 0xFF; rd((ad + i) & 0xFFFF, &b); printf("%02X", b); }
			printf("\n");
		} else if (!strcmp(cmd, "R") || !strcmp(cmd, "P")) {
			char a3[2048] = {0};
			sscanf(line, "%7s %399s %63s %2047s", cmd, a1, a2, a3);
			uint8_t* wr = (uint8_t*) p_retro_get_memory_data(RETRO_MEMORY_SYSTEM_RAM);
			size_t wl = p_retro_get_memory_size(RETRO_MEMORY_SYSTEM_RAM);
			unsigned bank = strtoul(a1, 0, 16), ad = strtoul(a2, 0, 16);
			size_t base = ad < 0xD000 ? ad - 0xC000 : bank * 0x1000 + (ad - 0xD000);
			if (cmd[0] == 'R') {
				int cnt = atoi(a3);
				for (int i = 0; i < cnt; i++) printf("%02X", wr && base + i < wl ? wr[base + i] : 0xFF);
				printf("\n");
			} else {
				for (size_t i = 0; a3[2 * i] && a3[2 * i + 1]; i++) {
					char hx[3] = {a3[2 * i], a3[2 * i + 1], 0};
					if (wr && base + i < wl) wr[base + i] = (uint8_t) strtoul(hx, 0, 16);
				}
				printf("ok\n");
			}
		} else if (!strcmp(cmd, "p")) {             /* p ADDR VAL: poke a byte (hex) */
			uint8_t b; poke = (int) strtoul(a2, 0, 16); rd(strtoul(a1, 0, 16) & 0xFFFF, &b); poke = -1;
			printf("ok\n");
		} else if (!strcmp(cmd, "s")) {
			FILE* f = fopen(a1, "wb");
			if (f) { fprintf(f, "P6\n160 144\n255\n"); fwrite(frame, 1, sizeof frame, f); fclose(f); }
			printf("ok\n");
		} else if (!strcmp(cmd, "w")) {
			if (wav) { wav_header(wav, wav_bytes); fclose(wav); }
			wav = fopen(a1, "wb"); wav_bytes = 0; if (wav) wav_header(wav, 0);
			printf("ok %d\n", rate);
		} else if (!strcmp(cmd, "W")) {
			if (wav) { wav_header(wav, wav_bytes); fclose(wav); wav = NULL; }
			printf("ok\n");
		} else if (!strcmp(cmd, "S") || !strcmp(cmd, "L")) {
			size_t sz = p_retro_serialize_size(); void* b = malloc(sz); int ok = 0;
			if (cmd[0] == 'S') { if (p_retro_serialize(b, sz)) { FILE* f = fopen(a1, "wb"); if (f) { fwrite(b, 1, sz, f); fclose(f); ok = 1; } } }
			else { FILE* f = fopen(a1, "rb"); if (f) { ok = fread(b, 1, sz, f) == sz && p_retro_unserialize(b, sz); fclose(f); } }
			free(b); printf(ok ? "ok\n" : "err\n");
		} else if (!strcmp(cmd, "c")) {             /* c OFF N: the cartridge RAM */
			uint8_t* sr = (uint8_t*) p_retro_get_memory_data(RETRO_MEMORY_SAVE_RAM);
			size_t sl = p_retro_get_memory_size(RETRO_MEMORY_SAVE_RAM);
			unsigned off = strtoul(a1, 0, 16); int cnt = n > 2 ? atoi(a2) : 1;
			if (cnt == 0) printf("%zu", sl);
			for (int i = 0; i < cnt; i++) printf("%02X", sr && off + i < sl ? sr[off + i] : 0xFF);
			printf("\n");
		} else if (!strcmp(cmd, "v")) printf("%u\n", vchk_n ? *vchk_n : 0);
		else if (!strcmp(cmd, "q")) break;
		else printf("?\n");
	}
	if (wav) { wav_header(wav, wav_bytes); fclose(wav); }
	return 0;
}
