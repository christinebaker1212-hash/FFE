/* Headless mGBA runner for SGB testing of the GB builds (palettes, border, packets).
 *
 * usage: sgbrun ROM FRAMES OUTPREFIX [--dmg | --cgb | --agb] [--press KEYS@FRAME+HOLD ...] [--shot FRAME ...]
 *        [--padfile FILE] [--nshot K ...]
 *   --padfile: one NES pad byte per NES frame (bit 0 right .. 7 A, as the NES latched it),
 *     applied while the runtime's NES frame count ($D830) is that frame (as firstdiff.py);
 *   --nshot K: screenshot when the NES frame count first reaches K (env SGBRUN_DUMP=1: also
 *     PREFIX_nNNNNN.mem: VRAM 0/1, WRAM $C000 + banks 1-7, OAM, HRAM);
 *   --sram FILE: initial cart RAM (e.g. the NES power-on save RAM in bank 0, as compare.sync_sram).
 *   --poke K ADDR=VAL,...: when the NES frame count first reaches K, write NES addresses (hex;
 *     $0000-$07FF = work RAM $C000.., $6000-$7FFF = cart RAM bank 0).
 *   KEYS: letters a b s(elect) t(start) u d l r, e.g. --press t@700+5
 *   Screenshots: OUTPREFIX_fNNNNN.ppm (256x224 with the SGB border, 160x144 with --dmg).
 * Build: gcc -O2 sgbrun.c -lmgba -o sgbrun   (Ubuntu: apt install libmgba-dev)
 */
#include <mgba/core/core.h>
#include <mgba/core/timing.h>
#include <mgba/core/blip_buf.h>
#include <mgba/core/config.h>
#include <mgba/internal/gb/gb.h>
#include <mgba/internal/sm83/sm83.h>
#include <mgba-util/vfs.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

struct press { int frame, hold; unsigned keys; };

/* the runtime's fault record / frame counters: DBG at CNT, NMI_CNT +$10, WAIT_CNT +$14,
   TEST_PAD +$1E (FF1 $D820, WRAM bank 1; FF3 $CD80: env GB_CNT=CD80) */
static unsigned CNT = 0xD820;
/* env GB_PRG=ff3: NES PRG-RAM pokes into FF3's map ($6000-$63FF WRAM $C800, $7000-$7FFF WRAM
   bank 1, save slots / save count in cart RAM bank 0); default: cart RAM bank 0 $A000 + a */
static int prg_ff3 = 0;

/* SGBRUN_LOTCHECK=1 (docs/gb-release-checklist.md 2): every instruction is decoded before it
   runs; reported: LCD switched off outside the vblank, VRAM writes in PPU mode 3, OAM writes
   in modes 2 / 3, OAM DMA or general-purpose HDMA outside the vblank, cart RAM left on at a
   frame end, cart RAM accessed while off. */
static struct { unsigned long lcd, vram, oam, odma, gdma, ram_frames, ram_off_acc, insns, ram_on_insns, vread, oread, pal; int ram_on; } lc;
static int lc_ly0;
static void lc_report(const char* what, struct mCore* core, unsigned addr, int f) {
	static int shown[8]; int k = what[0] % 8;
	if (shown[k]++ >= 5) return;
	struct GB* gb = core->board;
	printf("lotcheck: %s at %02X:%04X (write %04X), frame %d, LY %d mode %d\n", what,
	       gb->cpu->pc < 0x4000 ? 0 : gb->memory.currentBank, gb->cpu->pc, addr, f, gb->video.ly, gb->video.mode);
}
static int lc_target(struct mCore* core, unsigned* addr, unsigned* val) {   /* write target of the next insn */
	struct GB* gb = core->board; struct SM83Core* c = gb->cpu;
	unsigned pc = c->pc, op = core->busRead8(core, pc);
	unsigned n1 = core->busRead8(core, pc + 1), n2 = core->busRead8(core, pc + 2);
	*val = c->a;
	switch (op) {
	case 0x02: *addr = c->bc; return 1;
	case 0x12: *addr = c->de; return 1;
	case 0x22: case 0x32: case 0x77: *addr = c->hl; return 1;
	case 0x70: *val = c->b; *addr = c->hl; return 1; case 0x71: *val = c->c; *addr = c->hl; return 1;
	case 0x72: *val = c->d; *addr = c->hl; return 1; case 0x73: *val = c->e; *addr = c->hl; return 1;
	case 0x74: *val = c->h; *addr = c->hl; return 1; case 0x75: *val = c->l; *addr = c->hl; return 1;
	case 0x36: *val = n1; *addr = c->hl; return 1;
	case 0x34: case 0x35: *val = 0x100; *addr = c->hl; return 1;
	case 0xEA: *addr = n1 | n2 << 8; return 1;
	case 0xE0: *addr = 0xFF00 | n1; return 1;
	case 0xE2: *addr = 0xFF00 | c->c; return 1;
	case 0x08: *val = 0x100; *addr = n1 | n2 << 8; return 1;
	case 0xCB: if ((n1 & 7) == 6 && (n1 < 0x40 || n1 >= 0x80)) { *val = 0x100; *addr = c->hl; return 1; } return 0;
	}
	return 0;
}
static unsigned lc_read_addr(struct mCore* core) {           /* the address the next insn reads (or $10000) */
	struct GB* gb = core->board; struct SM83Core* c = gb->cpu;
	unsigned pc = c->pc, op = core->busRead8(core, pc), a = 0x10000;
	if (op == 0x0A) a = c->bc; else if (op == 0x1A) a = c->de;
	else if (op == 0x2A || op == 0x3A || op == 0x7E || op == 0x46 || op == 0x4E || op == 0x56 || op == 0x5E
	         || op == 0x66 || op == 0x6E || op == 0x34 || op == 0x35 || (op >= 0x86 && op <= 0xBE && (op & 7) == 6)) a = c->hl;
	else if (op == 0xFA) a = core->busRead8(core, pc + 1) | core->busRead8(core, pc + 2) << 8;
	else if (op == 0xCB && (core->busRead8(core, pc + 1) & 7) == 6) a = c->hl;
	return a;
}
static int lc_reads_sram(struct mCore* core) {                 /* the next insn reads [hl] / [bc] / [de] / [nn] in $A000-$BFFF */
	struct GB* gb = core->board; struct SM83Core* c = gb->cpu;
	unsigned pc = c->pc, op = core->busRead8(core, pc), a = 0x10000;
	if (op == 0x0A) a = c->bc; else if (op == 0x1A) a = c->de;
	else if (op == 0x2A || op == 0x3A || op == 0x7E || op == 0x46 || op == 0x4E || op == 0x56 || op == 0x5E
	         || op == 0x66 || op == 0x6E || (op >= 0x86 && op <= 0xBE && (op & 7) == 6)) a = c->hl;
	else if (op == 0xFA) a = core->busRead8(core, pc + 1) | core->busRead8(core, pc + 2) << 8;
	return a >= 0xA000 && a < 0xC000;
}
/* SGBRUN_SVBK=LO-HI (hex ROM banks, with SGBRUN_LOTCHECK): code in those banks (the translated
   game, FF3) must run with WRAM bank 1 selected; the first time it does not, the last 64 PCs */
static unsigned svbk_lo = 0, svbk_hi = 0;
static void svbk_check(struct mCore* core) {
	static uint32_t ring[64]; static unsigned ri = 0; static int shown = 0;
	struct GB* gb = core->board; unsigned pc = gb->cpu->pc, bk = pc < 0x4000 ? 0 : gb->memory.currentBank;
	ring[ri++ & 63] = bk << 16 | pc;
	if (shown >= 3 || pc < 0x4000 || pc >= 0x8000 || bk < svbk_lo || bk > svbk_hi) return;
	unsigned sv = core->busRead8(core, 0xFF70) & 7;
	static unsigned run = 0;                       /* (an ExRAM access switches to bank 6 for one
	                                                  instruction: flag 16 game instructions in a row) */
	if (sv == 1 || sv == 0) { run = 0; return; }
	if (++run < 16) return;
	run = 0;
	shown++;
	printf("svbk: game code %02X:%04X runs with WRAM bank %u; last PCs:", bk, pc, sv);
	for (int i = 0; i < 64; i++) { uint32_t v = ring[(ri + i) & 63]; printf(" %02X:%04X", v >> 16, v & 0xFFFF); }
	printf("\n");
}
static void lc_pre(struct mCore* core, int f) {
	struct GB* gb = core->board; unsigned addr, val;
	if (svbk_hi) svbk_check(core);
	unsigned lcdc = core->busRead8(core, 0xFF40); int on = lcdc & 0x80;
	lc.insns++; if (lc.ram_on) lc.ram_on_insns++;
	lc_ly0 = -1;
	if (!lc.ram_on && lc_reads_sram(core)) { lc.ram_off_acc++; lc_report("read of cart RAM while off", core, 0, f); }
	if (on) {                                      /* reads the hardware blocks ($FF on a real Color) */
		unsigned ra = lc_read_addr(core);
		if (ra >= 0x8000 && ra < 0xA000 && gb->video.mode == 3) { lc.vread++; lc_report("VRAM read in mode 3", core, ra, f); }
		if (ra >= 0xFE00 && ra < 0xFEA0 && gb->video.mode >= 2) { lc.oread++; lc_report("OAM read in mode 2/3", core, ra, f); }
	}
	if (!lc_target(core, &addr, &val)) return;
	if (getenv("SGBRUN_WWATCH")) {                 /* ADDR:BANK (hex): writes there in that WRAM bank */
		static unsigned wa = 0, wb = 0; static int wn = 0;
		if (!wa) sscanf(getenv("SGBRUN_WWATCH"), "%x:%x", &wa, &wb);
		unsigned sv = core->busRead8(core, 0xFF70) & 7; if (!sv) sv = 1;
		if ((addr & 0xFFF0) == (wa & 0xFFF0) && (addr < 0xD000 || sv == wb) && wn++ < 400)
			printf("wwatch: %04X <- %03X at %02X:%04X frame %d SVBK %u\n", addr, val,
			       gb->cpu->pc < 0x4000 ? 0 : gb->memory.currentBank, gb->cpu->pc, f, sv);
	}
	int ly = gb->video.ly, mode = gb->video.mode;
	if (addr < 0x2000) lc.ram_on = val < 0x100 && (val & 0x0F) == 0x0A;
	else if (addr >= 0xA000 && addr < 0xC000 && !lc.ram_on) { lc.ram_off_acc++; lc_report("write to cart RAM while off", core, addr, f); }
	else if (addr >= 0x8000 && addr < 0xA000 && on && mode == 3) { lc.vram++; lc_report("VRAM write in mode 3", core, addr, f); }
	else if (addr >= 0xFE00 && addr < 0xFEA0 && on && mode >= 2) { lc.oam++; lc_report("OAM write in mode 2/3", core, addr, f); }
	else if (addr == 0xFF40 && on && val < 0x100 && !(val & 0x80) && ly < 144) { lc.lcd++; lc_report("LCD off outside the vblank", core, addr, f); }
	else if ((addr == 0xFF69 || addr == 0xFF6B) && on && mode == 3) { lc.pal++; lc_report("palette write in mode 3", core, addr, f); }
	else if (addr == 0xFF46 && on && ly < 144) { lc.odma++; lc_report("OAM DMA outside the vblank", core, addr, f); }
	else if (addr == 0xFF55 && on && val < 0x100 && !(val & 0x80)) lc_ly0 = ly;    /* general-purpose HDMA: checked after */
}
static void lc_post(struct mCore* core, int f) {
	if (lc_ly0 < 0) return;
	struct GB* gb = core->board;
	if (lc_ly0 < 144 || gb->video.ly < 144) { lc.gdma++; lc_report("general-purpose HDMA outside the vblank", core, 0xFF55, f); }
}

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

/* FF3 test mode: when WAIT_CNT ($D834) moves, NMI_CNT ($D830) = the NES input clock at that
   waited-for frame ($FFFF: none), and the test pad slots refilled from there */
static void resync(struct mCore* core, uint16_t* clk, long nclk, unsigned* lastw,
                   unsigned char* pads, long npads) {
	unsigned w = core->rawRead8(core, (CNT + 0x14), 1) | core->rawRead8(core, (CNT + 0x15), 1) << 8;
	if (w == *lastw) return;
	*lastw = w;
	if (w >= (unsigned) nclk || clk[w] == 0xFFFF) return;
	unsigned c = clk[w];
	core->rawWrite8(core, (CNT + 0x10), 1, c & 0xFF);
	core->rawWrite8(core, (CNT + 0x11), 1, c >> 8);
	struct GB* gbm = (struct GB*) core->board;
	for (unsigned k = c; k < c + 32; k++) {
		unsigned char v = k + 1 < npads ? pads[k + 1] : 0, r = 0;
		for (int b = 0; b < 8; b++) if (v & (1 << b)) r |= 0x80 >> b;
		if (gbm->memory.sram && gbm->sramSize >= 0x8000) gbm->memory.sram[0x6000 + (k & 0xFF)] = r;
	}
}

int main(int argc, char** argv) {
	if (argc < 4) { fprintf(stderr, "usage: sgbrun ROM FRAMES OUTPREFIX [--dmg] [--press K@F+H] [--shot F]\n"); return 2; }
	int frames = atoi(argv[2]); const char* out = argv[3];
	int dmg = 0; struct press presses[256]; int np = 0; int shots[1024]; int ns = 0;
	int poke_at = 0; const char* poke_list = 0;
	int prof = getenv("SGBRUN_PROF") != 0; static uint32_t profs[2000000]; static uint32_t proff[2000000]; int prof2 = getenv("SGBRUN_PROF2") ? atoi(getenv("SGBRUN_PROF2")) : 0; unsigned p2tick = 0; int nprof = 0;
	const char* sram_path = NULL;
	unsigned char* pads = NULL; long npads = 0; int nshots[1024]; int nns = 0; int nshot_done[1024] = {0};
	for (int i = 4; i < argc; i++) {
		if (!strcmp(argv[i], "--dmg")) dmg = 1;
		else if (!strcmp(argv[i], "--cgb")) dmg = 2;
		else if (!strcmp(argv[i], "--agb")) dmg = 3;     /* a Game Boy Advance running a Color game */
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
		else if (!strcmp(argv[i], "--poke") && i + 2 < argc) { poke_at = atoi(argv[++i]); poke_list = argv[++i]; }
		else if (!strcmp(argv[i], "--padfile") && i + 1 < argc) {
			FILE* pf = fopen(argv[++i], "rb");
			if (!pf) { fprintf(stderr, "no padfile\n"); return 1; }
			fseek(pf, 0, SEEK_END); npads = ftell(pf); fseek(pf, 0, SEEK_SET);
			pads = malloc(npads); if (fread(pads, 1, npads, pf) != (size_t) npads) return 1; fclose(pf);
		}
	}
	if (getenv("GB_CNT")) CNT = strtoul(getenv("GB_CNT"), 0, 16);
	prg_ff3 = getenv("GB_PRG") && !strcmp(getenv("GB_PRG"), "ff3");
	int lotchk = getenv("SGBRUN_LOTCHECK") != 0;
	if (getenv("SGBRUN_SVBK")) sscanf(getenv("SGBRUN_SVBK"), "%x-%x", &svbk_lo, &svbk_hi);
	struct mCore* core = mCoreFind(argv[1]);
	if (!core || !core->init(core)) { fprintf(stderr, "no core for %s\n", argv[1]); return 1; }
	mCoreInitConfig(core, NULL);
	/* the model for every kind of cart header (a dual-mode cart would otherwise run as CGB) */
	const char* model = dmg == 3 ? "AGB" : dmg == 2 ? "CGB" : dmg ? "DMG" : "SGB";
	mCoreConfigSetValue(&core->config, "gb.model", model);
	mCoreConfigSetValue(&core->config, "sgb.model", model);
	mCoreConfigSetValue(&core->config, "cgb.model", model);
	mCoreConfigSetValue(&core->config, "cgb.hybridModel", model);
	mCoreConfigSetValue(&core->config, "cgb.sgbModel", model);
	mCoreConfigSetIntValue(&core->config, "sgb.borders", dmg ? 0 : 1);   /* --cgb: Game Boy Color */
	mCoreConfigSetIntValue(&core->config, "useBios", 0);
	mCoreConfigSetIntValue(&core->config, "volume", 0x100);   /* (SGBRUN_WAV: audible samples) */
	mCoreConfigSetIntValue(&core->config, "mute", 0);
	mCoreLoadConfig(core);
	unsigned w, h;
	core->desiredVideoDimensions(core, &w, &h);
	unsigned W = 256, H = 224;                       /* allocate for the largest (SGB border) */
	color_t* buf = calloc(W * H, sizeof(color_t));
	core->setVideoBuffer(core, buf, W);
	if (!mCoreLoadFile(core, argv[1])) { fprintf(stderr, "cannot load %s\n", argv[1]); return 1; }
	if (getenv("SGBRUN_WAV")) {
		core->setAudioBufferSize(core, 4096);
		// (mGBA sets the blip rates itself)

	}
	core->reset(core);
	if (sram_path) {
		FILE* sf = fopen(sram_path, "rb");
		if (!sf) { fprintf(stderr, "no sram file\n"); return 1; }
		static unsigned char sram[0x8000];
		size_t n = fread(sram, 1, sizeof sram, sf); fclose(sf);
		core->savedataRestore(core, sram, n, false);
		struct GB* gbm = (struct GB*) core->board;      /* (and straight into the cart RAM) */
		if (gbm->memory.sram && gbm->sramSize >= n) memcpy(gbm->memory.sram, sram, n);
	}
	char path[1024];
	/* SGBRUN_CLOCK=FILE (FF3 test mode): u16 per waited-for frame = the NES input clock at that
	   wait; whenever WAIT_CNT ($D834) advances, NMI_CNT ($D830) is set to it (as firstdiff.py),
	   so scripted input stays on the NES's game path whatever the GB's timing */
	static uint16_t clk[65536]; long nclk = 0; unsigned lastw = 0;
	if (getenv("SGBRUN_CLOCK")) {
		FILE* cf = fopen(getenv("SGBRUN_CLOCK"), "rb");
		if (cf) { nclk = fread(clk, 2, 65536, cf); fclose(cf); }
	}
	/* SGBRUN_WAV=FILE: the sound as 16-bit stereo, 96000 Hz (mGBA's buffer rate here) */
	FILE* wavf = NULL;
	if (getenv("SGBRUN_WAV")) {
		wavf = fopen(getenv("SGBRUN_WAV"), "wb");
		unsigned char hd[44] = { 'R','I','F','F',0,0,0,0,'W','A','V','E','f','m','t',' ',16,0,0,0,1,0,2,0,
			0x00,0x77,0x01,0, 0x00,0xDC,0x05,0, 4,0,16,0,'d','a','t','a',0,0,0,0 };
		fwrite(hd, 1, 44, wavf);
	}
	for (int f = 1; f <= frames; f++) {
		if (poke_list) {
			unsigned n = core->rawRead8(core, (CNT + 0x10), 1) | core->rawRead8(core, (CNT + 0x11), 1) << 8;
			if (n >= (unsigned) poke_at) {
				for (const char* p = poke_list; *p; ) {
					unsigned a, v; int used;
					if (sscanf(p, "%x=%x%n", &a, &v, &used) != 2) break;
					if (a < 0x800) core->rawWrite8(core, 0xC000 + a, -1, v);
					else if (prg_ff3 && a >= 0x7F38 && a <= 0x7F3A) core->rawWrite8(core, 0xA000 + a - 0x7F00, 0, v);
					else if (prg_ff3 && a >= 0x6000 && a < 0x6400) core->rawWrite8(core, 0xC800 + a - 0x6000, -1, v);
					else if (prg_ff3 && a >= 0x7000 && a < 0x8000) core->rawWrite8(core, 0xD000 + a - 0x7000, 1, v);
					else if (a >= 0x6000 && a < 0x8000) {
						struct GB* gbm = (struct GB*) core->board;   /* (cart RAM may be switched off) */
						if (gbm->memory.sram) gbm->memory.sram[a - 0x6000] = v;
					}
					p += used; if (*p == ',') p++;
				}
				poke_list = 0;
			}
		}
		unsigned keys = 0;
		for (int k = 0; k < np; k++)
			if (f >= presses[k].frame && f < presses[k].frame + presses[k].hold) keys |= presses[k].keys;
		if (pads) {
			unsigned n = core->rawRead8(core, (CNT + 0x10), 1) | core->rawRead8(core, (CNT + 0x11), 1) << 8;
			unsigned char m = n + 1 < npads ? pads[n + 1] : 0;   /* the pad of the frame being played */
			static const unsigned map[8] = { 1 << 4, 1 << 5, 1 << 7, 1 << 6, 1 << 3, 1 << 2, 1 << 1, 1 << 0 };
			for (int b = 0; b < 8; b++) if (m & (1 << b)) keys |= map[b];
			/* exact input: the ROM's test mode (TEST_PAD $D83E = $A5) reads the pad of the
			   frame after wait k from cart RAM bank 3 $A000 + (k & $FF) */
			if (f > 30) {
				core->rawWrite8(core, (CNT + 0x1E), 1, 0xA5);
				for (unsigned k = n; k < n + 32; k++) {
					unsigned char v = k + 1 < npads ? pads[k + 1] : 0, r = 0;
					for (int b = 0; b < 8; b++) if (v & (1 << b)) r |= 0x80 >> b;
					struct GB* gbm = (struct GB*) core->board;
					if (gbm->memory.sram && gbm->sramSize >= 0x8000) gbm->memory.sram[0x6000 + (k & 0xFF)] = r;
				}
			}
		}
		core->setKeys(core, keys);
		unsigned n_before = core->rawRead8(core, (CNT + 0x10), 1) | core->rawRead8(core, (CNT + 0x11), 1) << 8;
		if (prof2) {                                    /* SGBRUN_PROF2=K: PC + mapped bank every K instructions */
			uint32_t fc = core->frameCounter(core);
			while (core->frameCounter(core) == fc) {
				core->step(core);
				if (nclk && f > 30) resync(core, clk, nclk, &lastw, pads, npads);
				if (getenv("SGBRUN_TRAP")) {            /* PC = ADDR (bank 0): print the last 64 PCs (bank:pc) */
					static int ta = -1, ti = 0, done = 0; static uint32_t ring[64];
					if (ta < 0) ta = strtoul(getenv("SGBRUN_TRAP"), 0, 16);
					uint32_t pc = 0; core->readRegister(core, "pc", &pc); pc &= 0xFFFF;
					unsigned bk = ((struct GB*) core->board)->memory.currentBank;
					ring[ti++ & 63] = (pc < 0x4000 ? 0 : bk) << 16 | pc;
					if (pc == (unsigned) ta && !done) {
						done = 1; printf("trap at %04X, last PCs:", ta);
						for (int i = 0; i < 64; i++) { uint32_t v = ring[(ti + i) & 63]; printf(" %02X:%04X", v >> 16, v & 0xFFFF); }
						printf("\n");
					}
				}
				if (getenv("SGBRUN_CALLERS")) {         /* PC = ADDR (bank 0): the return address on the stack */
					static int ca = -1; if (ca < 0) ca = strtoul(getenv("SGBRUN_CALLERS"), 0, 16);
					uint32_t pc = 0; core->readRegister(core, "pc", &pc);
					if ((pc & 0xFFFF) == (unsigned) ca && nprof < 2000000) {
						uint32_t sp = 0; core->readRegister(core, "sp", &sp); sp &= 0xFFFF;
						unsigned ra = core->rawRead8(core, sp, -1) | core->rawRead8(core, sp + 1, -1) << 8;
						unsigned nn = core->rawRead8(core, (CNT + 0x10), 1) | core->rawRead8(core, (CNT + 0x11), 1) << 8;
						profs[nprof] = 0x2000000u | (unsigned) ((struct GB*) core->board)->memory.currentBank << 16 | ra; proff[nprof++] = nn;
					}
				}
				int take;
				if (getenv("SGBRUN_PROFC")) {           /* (with SGBRUN_PROFC: every PROF2 cycles, halts included) */
					static uint64_t nextc = 0;
					uint64_t t = mTimingGlobalTime(&((struct GB*) core->board)->timing);
					take = t >= nextc; if (take) nextc = t + prof2;
				} else take = ++p2tick >= prof2;
				if (take) {
					p2tick = 0;
					uint32_t pc = 0; core->readRegister(core, "pc", &pc); pc &= 0xFFFF;
					unsigned bank = pc < 0x4000 ? 0 : ((struct GB*) core->board)->memory.currentBank;
					unsigned nn = core->rawRead8(core, (CNT + 0x10), 1) | core->rawRead8(core, (CNT + 0x11), 1) << 8;
					if (nprof < 2000000) { profs[nprof] = bank << 16 | pc; proff[nprof++] = nn; }
					if (getenv("SGBRUN_PROF_SP") && nprof < 2000000) {   /* + the word at SP (a caller), for profiling helpers */
						uint32_t sp = 0; core->readRegister(core, "sp", &sp); sp &= 0xFFFF;
						unsigned ra = core->rawRead8(core, sp, -1) | core->rawRead8(core, sp + 1, -1) << 8;
						profs[nprof] = 0x1000000u | (unsigned) ((struct GB*) core->board)->memory.currentBank << 16 | ra; proff[nprof++] = nn;
					}
				}
			}
		} else if (lotchk) {                            /* SGBRUN_LOTCHECK: every instruction checked */
			uint32_t fc = core->frameCounter(core);
			while (core->frameCounter(core) == fc) {
				lc_pre(core, f);
				core->step(core);
				lc_post(core, f);
				if (nclk && f > 30) resync(core, clk, nclk, &lastw, pads, npads);
			}
			if (lc.ram_on) { lc.ram_frames++; lc_report("cart RAM on at a frame end", core, 0, f); }
		} else if (nclk) {                              /* exact resync: at the instruction where WAIT_CNT moves */
			uint32_t fc = core->frameCounter(core);
			while (core->frameCounter(core) == fc) {
				core->step(core);
				if (f > 30) resync(core, clk, nclk, &lastw, pads, npads);
			}
		} else
		core->runFrame(core);
		if (wavf) {
			static short buf[2 * 4096];
			blip_t* l = core->getAudioChannel(core, 0); blip_t* r = core->getAudioChannel(core, 1);
			int n;
			while ((n = blip_samples_avail(l)) > 0) {
				if (n > 4096) n = 4096;
				blip_read_samples(l, buf, n, 1); blip_read_samples(r, buf + 1, n, 1);
				fwrite(buf, 4, n, wavf);
			}
		}
		if (getenv("SGBRUN_LAG")) {                     /* SGBRUN_LAG=FILE: NES frame count per GB frame */
			static FILE* lf = NULL;
			if (!lf) lf = fopen(getenv("SGBRUN_LAG"), "wb");
			uint16_t v = f > 30 ? (core->rawRead8(core, (CNT + 0x10), 1) | core->rawRead8(core, (CNT + 0x11), 1) << 8) : 0;
			fwrite(&v, 2, 1, lf); fflush(lf);
		}
		if (prof) {                                     /* SGBRUN_PROF: PC of frames without a NES frame end */
			unsigned n_after = core->rawRead8(core, (CNT + 0x10), 1) | core->rawRead8(core, (CNT + 0x11), 1) << 8;
			if (n_after == n_before && nprof < 2000000) {
				uint32_t pc = 0; core->readRegister(core, "pc", &pc); pc &= 0xFFFF;
				unsigned bank = pc < 0x4000 ? 0 : core->busRead8(core, 0xFF8C);
				profs[nprof] = bank << 16 | pc; proff[nprof++] = n_after;
			}
		}
		int shot = (f == frames);
		for (int k = 0; k < ns; k++) if (shots[k] == f) shot = 1;
		if (nns) {
			unsigned n = core->rawRead8(core, (CNT + 0x10), 1) | core->rawRead8(core, (CNT + 0x11), 1) << 8;
			for (int k = 0; k < nns; k++) if (!nshot_done[k] && n >= (unsigned) nshots[k]) {
				nshot_done[k] = 1;
				core->desiredVideoDimensions(core, &w, &h);
				snprintf(path, sizeof path, "%s_n%05d.ppm", out, nshots[k]);
				if (getenv("SGBRUN_PEEK")) {                /* 16 bytes of WRAM from a hex address */
					unsigned a0 = strtoul(getenv("SGBRUN_PEEK"), 0, 16);
					printf("peek %d %04X:", nshots[k], a0);
					for (unsigned a = a0; a < a0 + 16; a++) printf(" %02X", core->busRead8(core, a));
					printf("\n");
				}
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
				if (getenv("SGBRUN_DUMP")) {                /* raw memory: VRAM banks 0/1 $8000-$9FFF, WRAM banks 0-7
				                                             $D000-$DFFF (0 = $C000), OAM, HRAM -> PREFIX_nNNNNN.mem */
					char mp[1100]; snprintf(mp, sizeof mp, "%s_n%05d.mem", out, nshots[k]);
					FILE* mf = fopen(mp, "wb");
					if (mf) {
						for (int b = 0; b < 2; b++) for (unsigned a = 0x8000; a < 0xA000; a++) fputc(core->rawRead8(core, a, b), mf);
						for (unsigned a = 0xC000; a < 0xD000; a++) fputc(core->busRead8(core, a), mf);
						for (int b = 1; b < 8; b++) for (unsigned a = 0xD000; a < 0xE000; a++) fputc(core->rawRead8(core, a, b), mf);
						for (unsigned a = 0xFE00; a < 0xFEA0; a++) fputc(core->busRead8(core, a), mf);
						for (unsigned a = 0xFF80; a < 0x10000; a++) fputc(core->busRead8(core, a), mf);
						fclose(mf);
					}
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
	if (wavf) {                                          /* finish the WAV header */
		long n = ftell(wavf) - 44; unsigned h[2] = { (unsigned) n + 36, (unsigned) n };
		fseek(wavf, 4, SEEK_SET); fwrite(&h[0], 4, 1, wavf); fseek(wavf, 40, SEEK_SET); fwrite(&h[1], 4, 1, wavf);
		fclose(wavf);
	}
	if (getenv("SGBRUN_SRAMOUT")) {                     /* the cart RAM at the end -> FILE */
		struct GB* gbm = (struct GB*) core->board;
		FILE* so = fopen(getenv("SGBRUN_SRAMOUT"), "wb");
		if (so && gbm->memory.sram) { fwrite(gbm->memory.sram, 1, gbm->sramSize, so); fclose(so); }
	}
	/* frame-wait counter of the runtime ($D830), to confirm the game ran */
	unsigned n = core->rawRead8(core, (CNT + 0x10), 1) | core->rawRead8(core, (CNT + 0x11), 1) << 8;
	printf("frames %d, video %ux%u, NES frame waits %u, KEY1 %02X\n", frames, w, h, n, core->busRead8(core, 0xFF4D));
	if (lotchk)
		printf("lotcheck: %lu instructions; LCD off outside vblank %lu, VRAM writes in mode 3 %lu, OAM writes in "
		       "mode 2/3 %lu, OAM DMA outside vblank %lu, GDMA outside vblank %lu, frames ending with cart RAM on %lu, "
		       "cart RAM accesses while off %lu, instructions with cart RAM on %lu, VRAM reads in mode 3 %lu, OAM reads "
		       "in mode 2/3 %lu, palette writes in mode 3 %lu\n", lc.insns, lc.lcd, lc.vram, lc.oam,
		       lc.odma, lc.gdma, lc.ram_frames, lc.ram_off_acc, lc.ram_on_insns, lc.vread, lc.oread, lc.pal);
	if (prof || prof2) for (int k = 0; k < nprof; k++) printf("%s %02X:%04X %u\n", (profs[k] >> 24) == 2 ? "C" : (profs[k] >> 24) ? "S" : "P", (profs[k] >> 16) & 0xFF, profs[k] & 0xFFFF, proff[k]);
	core->deinit(core);
	return 0;
}
