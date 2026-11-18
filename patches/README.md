# Patches (BPS)

Apply with any BPS patcher (Floating IPS, beat, Rom Patcher JS) or `python3 tools/bps.py apply`.
Work-in-progress builds; see the commit log for what each contains.

| Patch | Apply to (SHA-1 with iNES header) | Result (SHA-1) |
|---|---|---|
| `ff1_en.bps` | `Final Fantasy I, II (Japan).nes` `4b22c2c88fc71eacf270ea51ef218944bb4c536a` | Final Fantasy (English, MMC5) `76aa4d30f87dea57a9ccdeadeb0d9b93160d8f61` |
| `ff2_en.bps` | `Final Fantasy I, II (Japan).nes` `4b22c2c88fc71eacf270ea51ef218944bb4c536a` | Final Fantasy II (English, MMC5) `0e76a60d64c8cdd76f9b68e2f01ec8723a9a94da` |
| `ff3_en.bps` | `Final Fantasy III (Japan).nes` `c4443fc24625e3c2bb859525eb44b6b3a80e7c35` | Final Fantasy III (English, MMC5) `f6d8e8c9971cb0f01e268abbffe3202258898035` |

The results are MMC5 (mapper 5) ROMs: the FF I・II cartridge is split into two standalone
games, and FF III is moved to MMC5 for the room the English needs (1 MB). Use an emulator
with MMC5 support (Mesen, FCEUX, Nestopia, puNES...).
