# Improvements taken from the WonderSwan Color FF1 videos (2026-11-22)

The owner sent five play videos (v1-v5; the rar held a sixth copy of v5) of the Japanese
WonderSwan Color remake of Final Fantasy I and asked for its improvements and visual style
"WITHOUT changing the NES aesthetic or the Game Boy and Game Boy Color aesthetic".

I checked every frame at 2 fps, and the key moments at the full 60 fps: the encounter
transition, an enemy acting, a member attacking, enemy deaths, victory, every menu, the shops,
Options and the save screen. I then asked the owner which ideas to take.

This file records what was adopted, what was not and why, and how each item can be rebuilt in
the other Game Boy ports (FF2, FF3). The FF1 code is in `tools/gbn/src/btl5.s` (battle) and
`tools/gbn/src/loc.s` (the rest).

## What the remake does (seen in the videos)

| Area | Remake | Taken? |
|---|---|---|
| Encounter | the map spins and shatters into triangles, then a white flash | yes, after a mock-up (owner, 2026-11-22): twist + zoom and shattering strips (raster effects; no rotation on a Game Boy), white flash, the battle fades in from white |
| Battle field | painted backdrops, gradient blue windows with a bevelled frame | gradient windows yes on the Color (Options: Gradient On / Off), FF1's frame kept; backdrops no |
| Enemy acting | flashes white, then black with a white outline, twice (about 4 frames each), then "1 HIT" over it | yes (the owner allowed this one blink) |
| Member acting | darts forward in about 3 frames with the weapon raised, swings, "1 HIT" beside it | yes |
| Hit count | gold "n HIT" label over the attacker, the damage number over the target | yes |
| Enemy window | name and how many are left ("Goblin 4"), counting down | yes |
| Party window | name, HP current / max, MP | already (HP); MP: FF1 has spell charges per level |
| Command window | opens over the windows; "B Cancel" label | no (button hints declined) |
| Victory | one line at a time in a top banner | no: the owner chose the results window earlier |
| Town entry | the place's name in a banner at the top for a moment | yes |
| Main menu | party with portraits, LV, HP, MP; commands; Gil and play time; orbs; the place | yes (place, play time; the rest was already there) |
| Items | Use / Sort / Key Items; two columns with counts; a description line | yes (Use / Sort / Key Items) |
| Magic | Use / Forget; L / R to change member; MP shown; description line | Forget yes; L / R and MP already |
| Equipment | Equip / Optimal / Remove; L / R member; stats with arrows | Optimize yes; the rest already |
| Shops | the party with up-arrow / = per member; owned / equipped counts; magic: three slot pips per member and the jobs that can learn | counts and pips yes; per-member preview already |
| Config | B Dash On/Off, cursor Remember/Reset, message display, message speed, window colour R/G/B, bestiary | dash, cursor, window colour (Color only) yes; bestiary no |
| Save | three files, each with the party, place, Gil and time; "overwrite?" | yes (no place: FF1 saves put the party on the world map) |

## How each one is built (and how to rebuild it in another port)

### Battle

- **Enemy flash.**
  - *Build time* (`battle.py sil_banks`): for each enemy graphics page and each of the four
    graphic boxes (4x4 / 6x6 tiles), the box's pixels become colour 2 and a 1-pixel outline
    becomes colour 1. The outline is computed over the whole box, so it crosses tile edges.
    Stored in the enemy pages' layout (2 banks).
  - *Run time* (`btl5.s bt_eflash`): the acting enemy's silhouette is uploaded into BG tiles
    that are free while only the names window shows (`$C4-$EF`). Its cells are switched to
    them for 4 frames per phase, then restored from the map copy.
  - *Colours by system:*
    - Color: phases W / B through BG palettes 6 and 7. White: colour 2 white, outline black.
      Black: colour 2 black, outline white.
    - DMG / SGB: one palette, so the silhouette tiles are coded white on black and alternate
      with the picture.
  - *Fiends / Chaos* are too big for the free tiles: the Color turns their BG palettes white
    and back, rebuilt from the ROM. Don't read palette RAM back: mGBA can return 0.
  - *Elsewhere:* any game with enemies as BG tiles. Find tiles that are free at the moment of
    the action, build the silhouettes at build time, and switch the cells in V-Blank, a row
    per LY check.
- **Hit-count label.**
  - Our own 3x5 / 3x6 letters, made at build time for counts 1-39 ("n HIT" / "n HITS", three
    sprite tiles each, right-aligned so they end at the attacker).
  - Shown with the damage number in OAM 32-34, gold on the Color (OBJ palette 5), white on
    DMG / SGB (OBP1).
  - It reuses sprite tile `$F4`, which only "MISS!" uses, and a miss never has a label.
- **Enemy counts.** The names window draws each kind's count in the narrow 3-pixel digits at
  the end of its 56-pixel line, and clips the name 5 pixels earlier.
- **Dart.** `bt_dart` moves 4 px a frame for 2 frames, already in the attack or cast pose.
  It replaces FF1's walk (2 px every 2 frames) before and after the swing.

### Field and menus

- **Place-name banner.**
  - The dialogue box's window layer, cut by LYC at line 24 instead of 64, holds three rows
    (frame, name, frame).
  - Objects under it are hidden, and it lasts 150 frames.
  - It is shown when `load_map` loads a new map (not a reload after a menu or battle) whose
    place differs from the last one. A dialogue or any load removes it.
  - Names come from a table by map number (`ui.py LOC_NAMES`): the project's English, no
    floors. On DMG the letters must be in the field font (`text.field_codes` adds them).
- **Play time.** Counted in V-Blank once the field's loop has run, kept in unused bytes of the
  save page (`$F0-$F4` of page 0), so saves and the suspend point carry it with no format
  change.
- **Items: Use / Sort / Key Items.**
  - FF1 keeps items as counts by id, so Sort is a saved display order (healing first, a flag
    in the save page).
  - Key Items is a second list (the key items stay usable).
- **Optimize.**
  - Built on the equipment screen's own preview (apply, measure, undo).
  - Weapon: the candidate with the best Attack.
  - Armour: repeatedly the piece that raises Defense most, each tried in the row of the worn
    piece of its type.
- **Shops.** The speech window's free last line shows "Own n  Worn n" for the item under the
  hand. Magic shops show three pip glyphs (two new font codes, `$0A` / `$0B`) per member for
  the spell's level.
- **Options.** Moved to bank 99 and given:
  - B Dash On / Off;
  - Cursor Remember / Reset (clears the battle's remembered command, spell and target each
    turn);
  - the windows' colour on the Color. Palette 7 and the menus' palettes now come from a RAM
    copy (`win_pal`); the default is FF1's blue from the ROM.
  The saved record changed from "OP" to "OQ"; the old one is still read.
- **Forget.** SELECT on a learnt spell, with a hint window under the list and an A / B
  question.
- **Three save files.**
  - File k is at cart RAM `$A000 + $410 k`. File 1 is where the single save was, so old saves
    stay.
  - The file screen (bank 99) previews play time, names, the leader's level and Gil.
  - Continue loads a file; the inn and the camps save into one, with a question before
    overwriting. The boot's damaged-save check covers all three.

## Lessons (also in docs/gb-lessons.md)

- **Cross-bank calls are silent bugs.** The assembler can't see banks. Moving the Options to
  bank 99 left the title calling `opt_save` in bank 2's address space: New Game broke only
  after a soft reset. `tools/gbn/xbank.py SYM` lists every call / jp / jr to another bank. Run
  it after moving code; the only bank-0 entries left should be calls made while that bank is
  mapped.
- **A routine that switches the ROM bank and doesn't switch back** (`text_pals` used to select
  the common bank) is safe only from bank 0. Called from a banked module, it returns into the
  wrong bank.
- **Loop exits and flags.** `sv_any` fell out of its loop with carry clear ("a save exists"),
  which unlocked Continue with nothing to load. A function that answers with a flag needs an
  explicit `scf` / `and a` at every exit.
- **Count free space by `$FF` runs in the built ROM, not by the last label.** Bank 0 had
  ~1.7 KB free after the screen framework while its "used" figure said 15.9 KB.
- **Free tiles depend on the moment.** In battle, the names window uses only the first 28
  text tiles, so an enemy's action can borrow the other 44 before its message is drawn.

## Added after the mock-up (2026-11-22, owner: "it's okay to add the gradient windows and encounter transition")

- **Encounter transition** (`loc.s bt_trans2`, tables `battle.py trans_tables`, bank 103): per frame
  and line an SCX offset and a map-line offset, made at build time (26 frames of twist + zoom
  towards the party, 18 of 8-line strips sliding apart). A STAT mode-0 interrupt (`text.s stat_rx`)
  writes each next line's SCX / SCY from a WRAM buffer; the next frame's buffer is filled while
  this one shows. The fade to white: the Color through a 8-level table, DMG / SGB by shades (the
  SGB's colour 0 made white by a PAL01 packet, since all-zero shades show colour 0). The battle's
  masked load and fade-in then run from white on the Color (`fd_wh`). The party sprite follows
  the twist at its line. Any port: precompute the per-line tables; keep the handler to a few
  loads and two register writes; restore STAT / LYC after.
- **The party walks in** from the right edge (8 pixels apart, FF1's walking pose) before the first
  command (`btl5.s bt_walkin`).
- **Gradient windows (Color only; Options: Gradient)** (`loc.s gr_*`, `text.s stat_gr`): each window's
  inside colour runs from the chosen window colour at its top to a third of it at its bottom.
  Built from the windows the screen drew (`scr_win` records them): per line the last window drawn
  owns it; a record per line where a colour changes (5-bit steps: about 10-20 per window); the
  LYC interrupt one line before, the write in that line's H-Blank; the music in the longest gap;
  windows side by side with another top (the main menu's right column) take palette 0, a copy of
  the window palette (and the orbs' palette 6 goes with them). Paused during fades (the flat
  colour fades with the rest). The field's dialogue box and the place banner get their own list
  (with the box's cut). DMG / SGB stay flat (one palette for the screen).
- **Main menu crystals** centred exactly: a 2 x 2 grid with one-tile gaps in the 7 x 5 interior.

Lessons from this round: see docs/gb-lessons.md ("Shared work RAM").
