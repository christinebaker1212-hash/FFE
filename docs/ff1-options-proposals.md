# FF1 native build: Config pages and proposed new options (2026-11-25)

Owner (2026-11-25): "please suggest more options for the player to configure, and consolidate some
options into submenus in a Nintendo-like way, to save menu on the options screen."

## Built: Config in pages
The Config screen was one scrolling list of up to 16 settings. It now has the three settings people
change most, then three pages (a `>` after their names), as Nintendo's own Game Boy / Color menus
group their options:

| Config | Controls > | Window > | Game > |
|---|---|---|---|
| Battle Speed | B Dash | Color: Window Red / Green / Blue (live), Gradient, LCD (with the Konami Code) | Modern MP |
| Text Speed | Cursor | plain Game Boy: Window (Black / White) | EXP, Gold (with the codes) |
| Volume | Auto Retarget | (no Window page on the Super Game Boy: its windows are black) | No Encounters (Sound Test code) |

A or Right opens a page (its name becomes the header), B goes back to Config with the hand on that
page's entry, B on Config saves and leaves (as before). The list redraws in place, without a fade.
Fixed on the way: Volume always showed 0 whatever the setting (its value was never printed).

## Proposed new options (none built; pick any)
Each fits one of the pages above, so Config itself stays at six rows.

**Sound**
1. **Stereo / Mono** (Config or a Sound page). Game Boy Color and Pocket players with headphones get
   the channels panned; Mono sends every channel to both sides. Many Nintendo GBC titles offer it.
2. **Music / Sound Effects volume** as two settings. Needs per-channel mixing in the sound engine
   (moderate work); Volume today scales everything at once.

**Window**
3. **Window Frame** (Type 1-4): the window border in a few styles, a Final Fantasy tradition
   (FF4-FF6). Cheap: four sets of the eight frame tiles.

**Field (a new page, or Controls)**
4. **Reflections On / Off** and **Water Animation On / Off**, for players who prefer the NES look.
5. **Place Names On / Off** (the banner when entering a map).

**Accessibility (Window or a new page)**
6. **Reduce Flashing**: the encounter transition's white flash, the battle flashes (enemies acting,
   spells, the fiends' flash) and screen shakes made gentle or removed. Nintendo has shipped such a
   setting in later titles; it matters for photosensitive players.

**Battle (Controls or a new Battle page)**
7. **Damage Numbers On / Off** (FF3-style popping numbers; Off: only FF1's messages).
8. **Battle Messages: Short / Full** (Full: every message as FF1 shows it, including what the numbers
   already show).

Recommended first: Reduce Flashing (6), Window Frame (3) and Stereo / Mono (1): little work each,
and the kind a Nintendo-published Color game would have.
