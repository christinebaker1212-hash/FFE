/* Headless mGBA runner for SGB testing of the GB builds (palettes, border, packets).
 *
 * usage: sgbrun ROM FRAMES OUTPREFIX [--dmg] [--press KEYS@FRAME+HOLD ...] [--shot FRAME ...]
 *        [--padfile FILE] [--nshot K ...]
 *   --padfile: one NES pad byte per NES frame (bit 0 right .. 7 A, as the NES latched it),
 *     applied while the runtime's NES frame count ($D830) is that frame (as firstdiff.py);
 *   --nshot K: screenshot when the NES frame count first reaches K;
 *   --sram FILE: initial cart RAM (e.g. the NES power-on save RAM in bank 0, as compare.sync_sram).
 *   --poke K ADDR=VAL,...: when the NES frame count first reaches K, write NES addresses (hex;
 *     $0000-$07FF = work RAM $C000.., $6000-$7FFF = cart RAM bank 0).
 *   KEYS: letters a b s(elect) t(start) u d l r, e.g. --press t@700+5
 *   Screenshots: OUTPREFIX_fNNNNN.ppm (256x224 with the SGB border, 160x144 with --dmg).
 * Build: gcc -O2 sgbrun.c -lmgba -o sgbrun   (Ubuntu: apt install libmgba-dev)
 */
#include <mgba/core/core.h>
#include <mgba/core/timing.h>
#include <mgba/core/config.h>
#include <mgba/internal/gb/gb.h>
#include <mgba/internal/sm83/sm83.h>
#include <mgba-util/vfs.h>
#include <stdio.h>
#include <stdint.h>
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

/* env SGBRUN_VCHK=1 (Lot Check, docs/gb-release-checks.md 2.2): every CPU write to VRAM
   ($8000-$9FFF) in mode 3 or to OAM ($FE00-$FE9F) in mode 2 / 3 with the LCD on is counted;
   the first 40 are printed (VCHK bank:PC address mode LY). DMA / HDMA do not go through it. */
static void (*vchk_store8)(struct SM83Core*, uint16_t, int8_t);
static struct GB* vchk_gb;
static unsigned vchk_n, vchk_shown;
static void vchk_store(struct SM83Core* cpu, uint16_t a, int8_t v) {
	struct GB* gb = vchk_gb;
	if (gb->memory.io[0x40] & 0x80) {
		int m = gb->video.mode;
		if ((a >= 0x8000 && a < 0xA000 && m == 3) || (a >= 0xFE00 && a < 0xFEA0 && (m == 2 || m == 3))) {
			vchk_n++;
			if (vchk_shown < 40) {
				vchk_shown++;
				fprintf(stderr, "VCHK %02X:%04X wr %04X mode %d LY %d\n", cpu->pc < 0x4000 ? 0 : gb->memory.currentBank,
				        cpu->pc, a, m, gb->memory.io[0x44]);
			}
		}
	}
	vchk_store8(cpu, a, v);
}

int main(int argc, char** argv) {
	if (argc < 4) { fprintf(stderr, "usage: sgbrun ROM FRAMES OUTPREFIX [--dmg] [--press K@F+H] [--shot F]\n"); return 2; }
	int frames = atoi(argv[2]); const char* out = argv[3];
	int dmg = 0; struct press presses[256]; int np = 0; int shots[1024]; int ns = 0;
	int poke_at = 0; const char* poke_list = 0;
	unsigned callt = getenv("SGBRUN_CALLS") ? strtoul(getenv("SGBRUN_CALLS"), 0, 16) : 0; static uint32_t callr[2000000], callw[2000000]; int ncall = 0;
	int prof = getenv("SGBRUN_PROF") != 0; static uint32_t profs[2000000]; static uint32_t proff[2000000]; int prof2 = getenv("SGBRUN_PROF2") ? atoi(getenv("SGBRUN_PROF2")) : 0; unsigned p2tick = 0; int nprof = 0;
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
		else if (!strcmp(argv[i], "--poke") && i + 2 < argc) { poke_at = atoi(argv[++i]); poke_list = argv[++i]; }
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
	if (getenv("SGBRUN_VCHK")) {
		vchk_gb = (struct GB*) core->board;
		vchk_store8 = vchk_gb->cpu->memory.store8;
		vchk_gb->cpu->memory.store8 = vchk_store;
	}
	if (sram_path) {
		FILE* sf = fopen(sram_path, "rb");
		if (!sf) { fprintf(stderr, "no sram file\n"); return 1; }
		static unsigned char sram[0x8000];
		size_t n = fread(sram, 1, sizeof sram, sf); fclose(sf);
		core->savedataRestore(core, sram, n, false);
	}
	char path[1024];
	for (int f = 1; f <= frames; f++) {
		if (poke_list) {
			unsigned n = core->rawRead8(core, 0xD830, 1) | core->rawRead8(core, 0xD831, 1) << 8;
			if (n >= (unsigned) poke_at) {
				for (const char* p = poke_list; *p; ) {
					unsigned a, v; int used;
					if (sscanf(p, "%x=%x%n", &a, &v, &used) != 2) break;
					if (a < 0x800) core->rawWrite8(core, 0xC000 + a, -1, v);
					else if (a >= 0x6000 && a < 0x8000) core->rawWrite8(core, 0xA000 + a - 0x6000, 0, v);
					p += used; if (*p == ',') p++;
				}
				poke_list = 0;
			}
		}
		unsigned keys = 0;
		for (int k = 0; k < np; k++)
			if (f >= presses[k].frame && f < presses[k].frame + presses[k].hold) keys |= presses[k].keys;
		if (pads) {
			unsigned n = core->rawRead8(core, 0xD830, 1) | core->rawRead8(core, 0xD831, 1) << 8;
			unsigned char m = n + 1 < npads ? pads[n + 1] : 0;   /* the pad of the frame being played */
			static const unsigned map[8] = { 1 << 4, 1 << 5, 1 << 7, 1 << 6, 1 << 3, 1 << 2, 1 << 1, 1 << 0 };
			for (int b = 0; b < 8; b++) if (m & (1 << b)) keys |= map[b];
			/* exact input: the ROM's test mode (TEST_PAD $D83E = $A5) reads the pad of the
			   frame after wait k from cart RAM bank 3 $A000 + (k & $FF) */
			if (f > 30) {
				core->rawWrite8(core, 0xD83E, 1, 0xA5);
				for (unsigned k = n; k < n + 32; k++) {
					unsigned char v = k + 1 < npads ? pads[k + 1] : 0, r = 0;
					for (int b = 0; b < 8; b++) if (v & (1 << b)) r |= 0x80 >> b;
					struct GB* gbm = (struct GB*) core->board;
					if (gbm->memory.sram && gbm->sramSize >= 0x8000) gbm->memory.sram[0x6000 + (k & 0xFF)] = r;
				}
			}
		}
		core->setKeys(core, keys);
		unsigned n_before = core->rawRead8(core, 0xD830, 1) | core->rawRead8(core, 0xD831, 1) << 8;
		if (prof2) {                                    /* SGBRUN_PROF2=K: PC + mapped bank every K instructions */
			uint32_t fc = core->frameCounter(core);
			while (core->frameCounter(core) == fc) {
				core->step(core);
				if (callt) {                            /* SGBRUN_CALLS=HEX: return address at each entry */
					uint32_t pc = 0; core->readRegister(core, "pc", &pc);
					static int cbank = -2; if (cbank == -2) cbank = getenv("SGBRUN_BANK") ? (int) strtoul(getenv("SGBRUN_BANK"), 0, 16) : -1;
					if ((pc & 0xFFFF) == callt && ncall < 2000000 && (cbank < 0 || (pc & 0xFFFF) < 0x4000 || ((struct GB*) core->board)->memory.currentBank == cbank)) {
						uint32_t sp = 0; core->readRegister(core, "sp", &sp); sp &= 0xFFFF;
						unsigned ra = core->rawRead8(core, sp, -1) | core->rawRead8(core, sp + 1, -1) << 8;
						unsigned rb = ra < 0x4000 ? 0 : ((struct GB*) core->board)->memory.currentBank;
						if (getenv("SGBRUN_CALLSP")) { ra = sp; rb = 0; }   /* (SGBRUN_CALLSP: SP at the entry instead) */
						callr[ncall] = rb << 16 | ra; callw[ncall++] = core->rawRead8(core, 0xD830, 1) | core->rawRead8(core, 0xD831, 1) << 8;
					}
				}
				if (getenv("SGBRUN_LYAT")) {            /* SGBRUN_LYAT=PC: wait, LY, VBL_CNT each time PC is reached */
					static unsigned lyat = 0; if (!lyat) lyat = strtoul(getenv("SGBRUN_LYAT"), 0, 16);
					uint32_t pc = 0; core->readRegister(core, "pc", &pc);
					static int lbank = -2; if (lbank == -2) lbank = getenv("SGBRUN_BANK") ? (int) strtoul(getenv("SGBRUN_BANK"), 0, 16) : -1;   /* (SGBRUN_BANK=HEX: only in that ROM bank) */
					if ((pc & 0xFFFF) == lyat && (lbank < 0 || lyat < 0x4000 || ((struct GB*) core->board)->memory.currentBank == lbank)) fprintf(stderr, "L %u %u %u\n", core->rawRead8(core, 0xD830, 1) | core->rawRead8(core, 0xD831, 1) << 8,
						core->rawRead8(core, 0xFF44, -1), core->rawRead8(core, 0xD832, 1) | core->rawRead8(core, 0xFF05, -1) << 8);
					if ((pc & 0xFFFF) == lyat && getenv("SGBRUN_LYMEM") && (lbank < 0 || lyat < 0x4000 || ((struct GB*) core->board)->memory.currentBank == lbank)) {   /* (+ 8 bytes there) */
						unsigned a0 = strtoul(getenv("SGBRUN_LYMEM"), 0, 16); fprintf(stderr, "M");
						for (unsigned a = a0; a < a0 + 8; a++) fprintf(stderr, " %02X", core->busRead8(core, a)); fprintf(stderr, "\n"); }
				}
				if (getenv("SGBRUN_TRACE")) {           /* SGBRUN_TRACE=A-B: bank:PC SP of every instruction in waits A-B */
					static int ta = -1, tb = -1; if (ta < 0) sscanf(getenv("SGBRUN_TRACE"), "%d-%d", &ta, &tb);
					int w = core->rawRead8(core, 0xD830, 1) | core->rawRead8(core, 0xD831, 1) << 8;
					if (w >= ta && w <= tb) { uint32_t pc = 0, sp = 0; core->readRegister(core, "pc", &pc); core->readRegister(core, "sp", &sp);
						pc &= 0xFFFF; fprintf(stderr, "T %02X:%04X %04X %d", pc < 0x4000 ? 0 : ((struct GB*) core->board)->memory.currentBank, pc, sp & 0xFFFF, w);
						if (getenv("SGBRUN_STK") && pc == strtoul(getenv("SGBRUN_STK"), 0, 16)) for (int q = 0; q < 12; q++) fprintf(stderr, " %04X", core->rawRead8(core, (sp + 2 * q) & 0xFFFF, -1) | core->rawRead8(core, (sp + 2 * q + 1) & 0xFFFF, -1) << 8);
						fprintf(stderr, "\n"); }   /* (SGBRUN_STK=PC: + 12 stack words there) */
				}
				if (getenv("SGBRUN_MINSP")) {           /* SGBRUN_MINSP: lowest SP (and the wait) over the run */
					static unsigned minsp = 0xFFFF, minw = 0; uint32_t sp = 0; core->readRegister(core, "sp", &sp); sp &= 0xFFFF;
					if (sp >= 0xC000 && sp < minsp) { minsp = sp; minw = core->rawRead8(core, 0xD830, 1) | core->rawRead8(core, 0xD831, 1) << 8;
						uint32_t pc = 0; core->readRegister(core, "pc", &pc); fprintf(stderr, "minsp %04X wait %u pc %02X:%04X\n", minsp, minw, ((struct GB*) core->board)->memory.currentBank, pc & 0xFFFF); }
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
					unsigned nn = core->rawRead8(core, 0xD830, 1) | core->rawRead8(core, 0xD831, 1) << 8;
					if (getenv("SGBRUN_PROF_LY")) nn |= (unsigned) core->rawRead8(core, 0xFF44, -1) << 16;   /* (LY in bits 16-23 of the wait column) */
					if (nprof < 2000000) { profs[nprof] = bank << 16 | pc; proff[nprof++] = nn; }
					if (getenv("SGBRUN_PROF_SP") && nprof < 2000000) {   /* + the word at SP (a caller), for profiling helpers */
						uint32_t sp = 0; core->readRegister(core, "sp", &sp);   /* (SGBRUN_PROF_SPOFF=N: the word at SP + N) */
						sp = (sp + (getenv("SGBRUN_PROF_SPOFF") ? atoi(getenv("SGBRUN_PROF_SPOFF")) : 0)) & 0xFFFF;
						unsigned ra = core->rawRead8(core, sp, -1) | core->rawRead8(core, sp + 1, -1) << 8;
						profs[nprof] = 0x1000000u | (unsigned) ((struct GB*) core->board)->memory.currentBank << 16 | ra; proff[nprof++] = nn;
					}
				}
			}
		} else
		core->runFrame(core);
		if (getenv("SGBRUN_LAG")) {                     /* SGBRUN_LAG=FILE: NES frame count per GB frame */
			static FILE* lf = NULL;
			if (!lf) lf = fopen(getenv("SGBRUN_LAG"), "wb");
			uint16_t v = f > 30 ? (core->rawRead8(core, 0xD830, 1) | core->rawRead8(core, 0xD831, 1) << 8) : 0;
			fwrite(&v, 2, 1, lf); fflush(lf);
		}
		if (prof) {                                     /* SGBRUN_PROF: PC of frames without a NES frame end */
			unsigned n_after = core->rawRead8(core, 0xD830, 1) | core->rawRead8(core, 0xD831, 1) << 8;
			if (n_after == n_before && nprof < 2000000) {
				uint32_t pc = 0; core->readRegister(core, "pc", &pc); pc &= 0xFFFF;
				unsigned bank = pc < 0x4000 ? 0 : core->busRead8(core, 0xFF8C);
				profs[nprof] = bank << 16 | pc; proff[nprof++] = n_after;
			}
		}
		int shot = (f == frames);
		for (int k = 0; k < ns; k++) if (shots[k] == f) shot = 1;
		if (nns) {
			unsigned n = core->rawRead8(core, 0xD830, 1) | core->rawRead8(core, 0xD831, 1) << 8;
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
	for (int k = 0; k < ncall; k++) printf("C %02X:%04X %u\n", (callr[k] >> 16) & 0xFF, callr[k] & 0xFFFF, callw[k]);
	if (prof || prof2) for (int k = 0; k < nprof; k++) printf("%s %02X:%04X %u\n", (profs[k] >> 24) ? "S" : "P", (profs[k] >> 16) & 0xFF, profs[k] & 0xFFFF, proff[k]);
	if (getenv("SGBRUN_VCHK")) printf("VCHK total %u\n", vchk_n);
	core->deinit(core);
	return 0;
}
