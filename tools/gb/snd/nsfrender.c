/* Render one NSF track with libgme (NES reference for tools/gb/sndcmp.py).
   usage: nsfrender FILE.nsf TRACK(1-based) SECONDS OUT.wav [VOICE]
   VOICE: 0-4 = only that NES voice (pulse 1, pulse 2, triangle, noise, DMC); omitted: all.
   build: gcc -O2 tools/gb/snd/nsfrender.c -lgme -o build/nsfrender */
#include <gme/gme.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
static void w16(FILE* f, int v) { fputc(v & 255, f); fputc((v >> 8) & 255, f); }
static void w32(FILE* f, long v) { w16(f, v & 0xFFFF); w16(f, (v >> 16) & 0xFFFF); }
int main(int argc, char** argv) {
	if (argc < 5) { fprintf(stderr, "usage: nsfrender NSF TRACK SECONDS OUT.wav [VOICE]\n"); return 1; }
	const int rate = 48000;
	Music_Emu* emu; gme_err_t e = gme_open_file(argv[1], &emu, rate);
	if (e) { fprintf(stderr, "%s\n", e); return 1; }
	gme_ignore_silence(emu, 1);
	if (argc > 5) { int v = atoi(argv[5]); gme_mute_voices(emu, ~(1 << v)); }
	e = gme_start_track(emu, atoi(argv[2]) - 1); if (e) { fprintf(stderr, "%s\n", e); return 1; }
	long n = (long) (atof(argv[3]) * rate) * 2; short* buf = malloc(n * sizeof(short));
	gme_play(emu, n, buf);
	FILE* o = fopen(argv[4], "wb");
	fwrite("RIFF", 1, 4, o); w32(o, 36 + n * 2); fwrite("WAVEfmt ", 1, 8, o); w32(o, 16); w16(o, 1); w16(o, 2);
	w32(o, rate); w32(o, rate * 4); w16(o, 4); w16(o, 16); fwrite("data", 1, 4, o); w32(o, n * 2);
	fwrite(buf, 2, n, o); fclose(o); gme_delete(emu); return 0;
}
