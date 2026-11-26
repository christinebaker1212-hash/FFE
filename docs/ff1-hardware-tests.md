# FF1 native build: real hardware test checklist

The release requirements (`docs/gb-release-checks.md`) ask for tests on real Game Boy hardware.
Everything so far has been checked in SameBoy (with the strict VRAM/OAM checker), mGBA and
Gambatte only. This list is what to run on each machine you have. The build is
`build/FF1 native (English, GB-GBC).gb`; on an EverDrive, keep save files per ROM.

Tick each item per system: **DMG** (original Game Boy), **Pocket**, **SGB** (Super Game Boy
on a SNES), **CGB** (Game Boy Color), **GBA** (if you have one; it runs the Color mode).

## 1. Boot and saves
- [ ] Boots to the title in under a second; no garbage before the title (all systems).
- [ ] SGB: the border appears, the title colours are right, no flicker of the border.
- [ ] New Game → party screen → world map; walk 50 steps; save at an inn; power off for
  10 seconds; power on; Continue loads the file with the right place, Gil and time.
- [ ] Suspend from the main menu; power off; Continue offers the Suspend Point and loads it.
- [ ] Soft reset (A + B + START + SELECT) from the map, a menu, a battle and a fade: back to
  the title each time, the save untouched.
- [ ] Three save files: save to file 2, load file 2, file 1 unchanged.

## 2. Picture (look for flashes, torn lines, wrong tiles)
- [ ] Town walk (Coneria, then Onrac): water moves, reflections in the canals, people walk
  without flicker; the dialogue box opens and closes cleanly.
- [ ] World map (B + SELECT on the overworld): the picture draws row by row with the tone.
- [ ] SELECT on the map: the shown member changes at once, never disappears.
- [ ] Ship and airship: take off, land, board, leave; the reflection under the ship.
- [ ] Bestiary (title → Extras): hold down to scroll fast; no row shows a wrong number.
- [ ] Every menu screen: Items, Magic, Equip (and Packs with SELECT), Status, Order, Config;
  on the Color also with the gradient window on and off.
- [ ] Shops: buy, sell, magic shop descriptions; inn; clinic.
- [ ] Color only: Config → LCD colour modes; the window colour; no wrong colour after loads.

## 3. Battles
- [ ] A random battle on each system: commands, magic, items, target hand, damage numbers,
  CRITICAL!, the results window.
- [ ] A fiend (any) and Chaos if you reach them: the hand beside the picture, the defeat
  animation.
- [ ] Run away; game over (let the party die once): FF1's message and the fade.
- [ ] Battle speed 1 and 8 (Config): no slowdown in long messages.

## 4. Sound
- [ ] Title, town, overworld, ship, airship, battle, victory, shop music: no buzz, no clicks on
  volume changes, no stuck note after a battle or a menu.
- [ ] DMG / Pocket: fades of the music sound smooth (the volume steps are hardware-specific).

## 5. Speed (no slowdown allowed)
- [ ] Walk the world map and a town for a minute on DMG and CGB: steps never pause.
- [ ] Battles with nine small enemies: no pause when the hits and numbers show.
- [ ] Loads (doors, stairs, battle start) take about as long as on the NES.

## 6. Lot Check items that only hardware shows
- [ ] GBA: the Color mode runs; the picture is the GBA's darker LCD (Config → LCD colour GBA
  mode should look right there).
- [ ] Pocket: the plain Game Boy mode, same as DMG.
- [ ] Battery save survives a battery swap of the console (not the cartridge).

## Reporting
For any fault: the system, what you did just before, a photo of the screen if you can, and
whether it happens again after a soft reset. Faults found only on hardware are the most
valuable ones: they mean the emulators differ there.
