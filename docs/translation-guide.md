# Translation guide (binding for every translator, human or AI)

Source: the Japanese text extracted from the original ROMs (`script/<game>/*.json`).
Each entry has `ja` (original, do not edit) and `en` (the translation you write).
No existing English translation (official or fan) may be used as a source or a reference.
Every decision comes from the Japanese.

## 1. Fidelity
- Translate what the Japanese **says**, in its register: royal/archaic speech stays
  formal (わし, じゃ, そなた → "I", "thee/you", old-fashioned phrasing); rough speech
  stays rough (pirates, thugs: おれ, 〜だぜ, 〜しな!); children sound like children;
  dialect or verbal tics get an English equivalent that keeps their flavour.
- **No censorship.** Death, killing, religion, alcohol, insults, crude jokes, innuendo:
  translate as written. Do not soften ("しね!" is "Die!", not "Take this!").
- Do not add jokes, references, or information that is not in the Japanese. Do not
  drop anything either: every sentence, interjection and trailing ‥‥ has to be there.
- The text is all kana, so homophones are ambiguous. Resolve them from context
  (surrounding lines, location, speaker). If a line is genuinely ambiguous, choose
  the most likely reading and record the alternative in the glossary notes.

## 2. Names (full length, never abbreviated)
- Write every name in full. There is **no character limit**: the ROM engine will be
  expanded to fit. "ミスリルハンマ" (clipped by the original 7-tile slot) becomes
  "Mythril Hammer"; "ストライ" (clipped) becomes "Strength" only if that is clearly the
  intended word; otherwise record it in the glossary.
- Katakana that spells an English (or other foreign) word: write that word
  (ポーション → Potion, ブリザド → Blizzard, ミスリル → Mythril, グラシャラボラス → Glasya-Labolas).
- Coined game terms: keep the coinage visible (ケアル → Cure, ケアルア → Cura,
  ケアルダ → Curada, ケアルガ → Curaga, ファイラ → Fira, ファイガ → Firaga,
  サンダラ → Thundara, ブリザラ → Blizzara). The suffixes -ra/-da/-ga are kept as-is.
- Hiragana or native-word names are translated by meaning (どくけし → Antidote,
  めぐすり → Eye Drops, ねこのつめ → Cat Claw, ひりゅうのつめ → Flying Dragon Claw).
- Proper names: transliterate faithfully (サスーン → Sasune, ウル → Ur, トパパ → Topapa).
  Record every proper name in `docs/glossary-<game>.md` and use it **consistently**.
- Type icons in names (`[60]`–`[75]` in FF3, `[6E]`–`[77]` in FF2) stay at the start of
  the name exactly as given.

## 3. Formatting tokens — copy them exactly
| Token | Meaning |
|---|---|
| `\n` | line break. Keep the same breaks where the Japanese has them (they separate lines/speakers). Do not add or remove breaks to manage width: the inserter rewraps long lines. |
| `{XX}` | control code (name, number, item insert…). Keep every one, in the position where it fits the English sentence. |
| `{XX:YY}` | control code with parameter (e.g. `{14:03}` = indent to column 3, `{18:2F}` = insert name-table entry 0x2F). Keep. Column codes `{14:..}` stay at the start of their line. |
| `{COL:XX}` | FF3 epilogue: column/centring. Keep at the start of the line. |
| `[XX]` | special tile (icon, blank). Keep. `[77][79]` in FF3 = "HP". |
| `　` (full-width space) | separator. Use normal English spacing instead; leading full-width spaces that indent a line should be kept as the same number of ordinary spaces. |

Inserted names (`{18:xx}`, `{02}`, `{10:02}`, etc.) are nouns: write the sentence so the
inserted word reads naturally ("{18:2F} Castle", "Give {02} to me").

## 4. Dialogue punctuation
- `名前「text` (speaker name + 「): write `Name: "text"` — close the quote at the end of
  that speaker's speech (before the `\n` that starts another speaker, or at the end).
- `「text` with no name: `"text"`. FF3 also uses `『` for the party's own lines: also `"text"`.
- `‥‥` → `...`; `!!` / `!?` / `??` keep as written; `ー` stretching a word ("すごーい")
  → stretch the English ("Amaaazing!").
- Use straight ASCII quotes and apostrophes only (`"` `'`). Allowed characters:
  A–Z a–z 0–9 space and `. , ! ? ' " - : ; ( ) / % & + …` (no other symbols).

## 5. Menus and system words
Short labels (menus, commands, statuses) get the clearest full English word: たたかう →
Fight, にげる → Run, まほう → Magic, そうび → Equip, ちから → Strength. Do not
abbreviate; the menu code gets widened.
