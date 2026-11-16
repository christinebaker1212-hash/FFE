# FFE — Faithful English translations of Final Fantasy I, II and III (Famicom)

A from-scratch English translation of the three Famicom Final Fantasy games,
done directly from the Japanese ROM text. It does not use any existing human
translation as a source.

ROM images are **not** included and must never be committed. The patches target:

| Game | File | SHA-1 (with iNES header) |
|---|---|---|
| Final Fantasy I・II (Japan) | `Final Fantasy I, II (Japan).nes` | `4b22c2c88fc71eacf270ea51ef218944bb4c536a` |
| Final Fantasy III (Japan) | `Final Fantasy III (Japan).nes` | `c4443fc24625e3c2bb859525eb44b6b3a80e7c35` |

## Translation rules (set by the project owner — binding)

1. **Absolute authenticity.** Translate what the Japanese says, in its tone and
   register. Do not soften, localize, modernize or "improve" the content.
2. **No censorship whatsoever.** Religious, violent, crude or sexual content
   and names stay as they are in the Japanese.
3. **Full-length names.** Enemy, item, magic, job and other name tables
   get expanded (code + ROM space) so each name is shown in full, as the
   Japanese player saw it. Do not abbreviate a name to fit an old byte budget.
4. **Identical experience.** Keep line breaks, pauses (‥‥), who-speaks
   markers and pacing as close to the original as the English allows. Every
   string in the game is translated: dialogue, menus, battle text, names,
   credits and the title/intro screens.

## Layout

- `tools/` — analysis and build tools (Python 3)
  - `dis6502.py` — 6502 disassembler; `tiles.py` — 2bpp tile viewer
  - `emu/` — patch + script to build a headless emulator (cynes) with 512KB
    MMC1 support, used to check text in-game
  - `ff3/` — FF III character table and script extractor
- `docs/` — technical notes on each game's text engine
- `script/` — extracted Japanese script and English translation, one file per
  table (JSON: `id`, `ja`, `en`)
