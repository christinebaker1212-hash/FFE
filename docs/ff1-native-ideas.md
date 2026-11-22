# FF1 native build: ideas for menus and battle (2026-11-22)

Suggestions for the owner to choose from. Each uses something the Game Boy / Game Boy Color
offers, or fixes something a 160 x 144 screen makes awkward. Owner's choices (2026-11-22): battle backdrops, the battle conveniences (remembered cursor,
damage numbers, results window), Options and dash are built (docs/ff1-native.md item 18);
HP bars and Select-repeat declined. The rest is open. Where
an idea needs FF1 graphics, they come from the user's ROM at build time, as everything else.

## Menus

1. **Title logo.** FF1's own "FINAL FANTASY" picture (the one under the bridge / ending
   story on the NES) above Continue / New Game, read from the ROM. The title is now three
   small windows on black.
2. **HP bars.** A small bar under each member's HP on the main menu and the target screen:
   green / yellow / red on the Color, shades on DMG / SGB. Reads faster than "60/ 98".
3. **Status words to icons.** Poison / Stone / Dead as 8 x 8 icons in FF3's style (drawn,
   like the item bag), so the party lines keep their numbers when someone is afflicted.
4. **Target screen with the pictures.** The item / spell target screen still uses the old
   text-only party list, because the prompts run up to 6 lines. Choice: shorter prompts
   ("Use on whom?") with the party pictures, or keep FF1's texts as now.
5. **Options screen** (as the recompiled build had): message speed (now only on the title),
   battle message speed, text typing speed, BGM / SFX volume, kept in the save.
6. **Equipment: Optimize.** One command that puts on the best weapon / armour the member can
   use from the party's packs (the comparison code already exists for the preview).
7. **Items: Sort.** Arrange the pack by kind (healing, key items, others), as later FF
   games and most Game Boy RPGs do.
8. **Shops: what you own.** "Own 2 / Equipped 1" beside the item being bought.
9. **Magic: a one-line effect** under the list for the spell at the hand (FF1's spell
   descriptions are in the ROM), and the MP cost shown with the spell.
10. **Dash.** Hold B to walk at double speed on the field (common in Game Boy RPGs; an option,
    since it changes FF1's pace).
11. **World map labels.** The town / dungeon name of the mark nearest the party.
12. **Super Game Boy menu colours.** The gold labels and green / red previews show only on
    the Color; on the SGB they could get their own palette (one ATTR_BLK area per screen).

## Battle

1. **Battle backdrops.** FF1's scenery strips (forest, cave, sea, ...) from the ROM behind the
   enemies, instead of black: the single biggest visual gain, and the Color shows them in
   their NES colours.
2. **HP bars in the party window**, coloured as in the menus; a member's line turns red at
   low HP (a colour change, no blinking).
3. **Damage numbers over the target** as small sprites for a moment, as Final Fantasy
   Legend does, beside the message window's words (the owner chose style A messages; this
   would add to them, not replace them).
4. **Remembered cursor.** Each member's last command and target kept for the next turn.
5. **Repeat last turn.** Holding Select at the command window repeats every member's last
   commands (a Game Boy-friendly "auto battle").
6. **Status icons** on the party window instead of words (as menu idea 3).
7. **Results window.** Experience, Gil, level ups and stat gains on one screen at the end,
   instead of a run of messages.
8. **Turn order.** A small marker by the member who acts next (no blinking: a fixed mark).
9. **Enemy names on the CGB in their palette colour**, so the names window matches the
   enemies drawn above it.
