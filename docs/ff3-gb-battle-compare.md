# FF3 battle: what FF3 already does vs FF1 GB's conveniences

Owner (2026-11-26): FF1's conveniences carry over, but "FF3 has some of these already programmed
in, and some of them are better. Determine in the battle screens whether or not our
implementation is better or worse, and prefer adaptation of ours to fit FF3 style where they are
roughly the same, or ours has an edge."

Sources: the English NES build (`build/ff3_en.nes`) run in cynes from New Game into the first
Altar Cave battle, one round recorded frame by frame (Fight on all four members); the
everything8215/ff3 listing (`build/ref/ff3/ff3j.asm`, banks $2F-$35 battle). Not seen on screen
yet: spells, healing, target selection, the encounter transition, results with level ups. Rows
marked "listing" rest on the code only and get a screen check when the battle is built.

## FF3's battle screen (NES, as seen)
- Enemies left, party in a column on the right; each member steps forward to act, swings, and
  steps back. The acting enemy darkens (flash) before it attacks.
- Windows along the bottom: attacker (top left), action / "n hits" / "Miss!" (top right), target
  (middle left), message (full width: "Critical hit!", "Defeated the enemy!"), and the party
  window (name, HP current / max) to the right.
- Damage numbers are sprites over the target (bounce, then vanish); a miss shows a sprite word.

## Verdict per feature
| Feature | FF3 itself | FF1 GB | Verdict for FF3 GB |
|---|---|---|---|
| Damage / healing numbers | Yes: sprite numerals over the target, red for damage, green for healing (listing: $31 $A249-$A25B, "green numerals"); a miss shows a sprite word | FF3-style popping numbers (modelled on FF3), MISS! | **FF3's own** (it is the original of ours). The miss sprite is still the Japanese "ミス!!" in the English NES build: draw it as "Miss!" (translation gap to fix) |
| Hit count | "n hits" in the action window (top right) | gold "n HIT(S)" label over the attacker | **Ours, FF3 wording**: the label over the attacker frees a window row on 160 x 144; text "2 hits" / "1 hit" in FF3's words, not "HITS" |
| Critical | "Critical hit!" as a message line (one more message wait) | CRITICAL! label with the damage number | **Ours, FF3 wording**: label "Critical hit!" beside the number, no extra message wait |
| Acting enemy flash | Yes (the enemy darkens) | WonderSwan flash white / black twice | **FF3's own** |
| Member steps forward / swing | Yes (walk forward, swing, walk back) | dart forward 2 frames | **FF3's own** movement and timing |
| Auto-retarget | Built in: a physical attack on a dead / stone / jumping target picks another at random (listing: $30 $9E8F-$9E9F) | Auto Retarget option (FF1 wastes the attack) | **FF3's own** (no option needed) |
| Remembered command / target | No: the command cursor starts at the top each turn (listing: $34 $9949) | Remembered (Config: Cursor Remember / Reset) | **Ours**, as a Config option, default as FF3 (Reset) |
| Hold A for quick selection | No | Yes | **Ours** |
| Enemy names window | names only ("Goblin") | name + how many are left | **Ours**: FF3's window with the count in small digits |
| Spell / ability name | in the action window (top right) | top window for spell / target names | **FF3's own** (the same idea, already there) |
| Ailments in the party window | the status word in the member's line | icon bubbles by the members, icons on the lines | **About equal: ours adapted**: FF3's status word stays in the line; icons only where the word does not fit (to decide on the mock-up) |
| Low-HP colours | no | gold under a quarter, red dead (Color) | **Ours** (Color) |
| Results | one message line at a time | one results window | **Ours**, FF3's wording |
| Messages | only what numbers cannot show (few) | the same rule (owner, FF1 item 26) | **FF3's own** (already so) |
| Enemy deaths | FF3's dissolve | sliding strips / fiend flash | **FF3's own** |
| Encounter transition | FF3's own effect | twist / zoom / strips, white flash | **FF3's own**, native (to check on screen first) |
| Message / battle speed | Text Speed 1-8 on the title (seen: "Text Speed 6") | Battle Speed in Config | **FF3's own setting**, also offered in Config |
| Target numerals | FF3 marks targets with numeral sprites while choosing (listing: battle graphics $07, $7E0F) | hand cursor | **FF3's own** (look at it on screen first) |

## Seen on the NES English build (not GB issues, for the owner)
- The miss sprite reads "ミス!!" (kana), untranslated.
- Six-letter names show as four letters in the party window on some frames ("BBBB 26/ 32") and
  as six on others; to look at when the party window is laid out.
