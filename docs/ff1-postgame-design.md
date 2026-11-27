# FF1 post-game: the Soul of Chaos dungeons (design proposal)

Owner's request (2026-11-27): add Dawn of Souls' bonus dungeons to the FF1 native build, keeping
the Dawn of Souls names, their places on the world map and the dungeons' actual design, adapted to
the NES look. Status: **proposal, waiting for the owner's decisions (section 9)**. Nothing is built.

Sources: the FINAL FANTASY wiki (finalfantasy.fandom.com, read through its public API on
2026-11-27): the pages "Soul of Chaos (Final Fantasy)", "Earthgift Shrine", "Hellfire Chasm",
"Lifespring Grotto", "Whisperwind Cove (Final Fantasy)", every enemy and boss page in
"Enemies in Final Fantasy" / "Bosses in Final Fantasy", and the pages' map images (a full map of
every floor, 16 px per tile). Positions on the world map were matched to the user's ROM (its own
overworld rows and entrance table), not guessed.

Mock-ups (made from the user's ROM graphics and the build's own font; not in the repository):
1. the world map with the four entrances;
2. the entrances on the Game Boy screen (sealed and open);
3. Earthgift floors: the Dawn of Souls map and the same floor in FF1's Earth Cave tiles;
4. a boss alcove as an FF1 room (door from the corridor, black behind it; inside);
5. screens inside: floor banner, a Mount Gulg floor, a new monster in battle, defeat.

## 1. What Dawn of Souls does (all four dungeons)

- Four optional dungeons, one per element. Each is sealed by a statue of its Fiend and opens when
  that Fiend falls and its crystal is lit again: **Earthgift Shrine** (Earth, Lich), **Hellfire
  Chasm** (Fire, Marilith), **Lifespring Grotto** (Water, Kraken), **Whisperwind Cove** (Wind,
  Tiamat).
- Length: 5 / 10 / 20 / 40 floors after the entrance floor.
- Floors are drawn at random from the dungeon's set; the boss floors are fixed (Earthgift B5;
  Hellfire B5, B10; Lifespring B5, B10, B20; Whisperwind B10, B20, B30, B40).
- No way out except on a boss floor, and only after beating a boss there: a portal back to the
  world map. A floor with two bosses allows one per run, so Earthgift takes 4 runs, Hellfire 2,
  Lifespring 2, Whisperwind 1.
- Losing a battle inside ejects the party to the world map (no Game Over), keeping EXP and items.
- Treasure: each floor has a fixed list; the number of chests varies and they are shuffled each run.
- New monsters, new items and equipment, bosses from Final Fantasy III-VI.

## 2. Entrances on the world map (from the user's ROM)

| Dungeon | Place (overworld metatile x, y) | How it is reached | Entrance graphic (FF1's own) |
|---|---|---|---|
| Earthgift Shrine | (132, 141): the bottom edge of the mountains north-west of Cornelia, grass below, sea to the south-west, forest to the east | on foot | cave mouth (Earth Cave's tile $0E), in the mountains' bottom edge row as FF1 places its caves |
| Hellfire Chasm | (97, 60): the marsh of the long Cardia island (FF1's Cardia cave at (93, 58)) | ship / airship, then on foot | Cardia cave tile ($67) |
| Lifespring Grotto | (95, 163): the Aldean Sea, off the Dwarf Cave's headland by the canal's mouth | ship, sailing onto the whirlpool | a whirlpool: new tile (the sea's colours; FF1 has none) |
| Whisperwind Cove | (187, 179): the river below the mountains west of the Ice Cave (197, 183) | canoe | cave mouth ($0E) in the mountains' bottom edge row, facing the river |

Positions are matched to the PSP screenshots' surroundings within a tile or two; the final spots
are checked against Dawn of Souls footage when built.

Sealed: the Fiend's statue stands in front of the entrance (made at build time from FF1's own
battle picture of that Fiend in the user's ROM: grey stone, 32 x 32, mock-up 2). Talking to it:
a line such as "A statue of Lich bars the way." (wording: decision D3). It is gone once the Fiend
is beaten.

## 3. The dungeons

### Earthgift Shrine (Earth; after Lich; 5 floors; bosses from FF3)
- Entrance: Giant's Cave look. Floors B1-B4 at random from: Altar Cave x2 (Cavern of Earth look,
  short), an endless desert (loops; palm trees in threes point the way to the oasis stairs; the
  Abyss Worm 1/64), a dark forest maze with NPCs that start fixed battles and block paths.
- B5 (fixed): four boss alcoves behind doors, a central altar room; one boss per run:
  **Two-Headed Dragon** (4,500 HP), **Cerberus** (4,000), **Echidna** (4,800), **Ahriman**
  (5,000); a Megalixir chest after Ahriman.
- Monsters: Black Goblin, Wild Nakk, Gloom Widow, Desertpede, Catoblepas, Abyss Worm, Skuldier
  (encounter rates per area are on the wiki page: e.g. Altar Cave 27/64 Black Goblin x1-5).
- Chests: B1-B4 lists of four (Hi-Potion, Spider's Silk, White Curtain, Remedy / ... / Elven Cloak),
  2-3 chests on Altar Cave floors, 4 on the desert and the forest.

### Hellfire Chasm (Fire; after Marilith; 10 floors; FF4's Archfiends)
- Entrance, boss floors and four random floors: Mount Gulg (lava floors hurt every step, no
  encounters on lava). Two Waterfall Cavern floors (one with roaming NPCs and glittering patches
  that start fixed battles). A fire shrine (Sunken Shrine look, red tiles hurt every few seconds,
  bats in the way). Three overworld maps (one per run: on foot, a ship, an airship, the pirate
  Thule; the airship after Thule and a desert oasis).
- B5: **Scarmiglione** (4,000 then 7,046) or **Cagnazzo** (7,968). B10: **Barbariccia** (12,954)
  or **Rubicante** (15,000).

### Lifespring Grotto (Water; after Kraken; 20 floors; FF5)
- Sunken Shrine look for the entrance, boss floors and six random floors; three Chaos Shrine
  floors; Cavern of Ice (spike floors); Dragon Caves (no random battles: Dark Bahamut sends you
  after dragons you talk to); Flying Fortress; Marsh Cave; a flooded village crossed by canoe; a
  village of dancers; a library maze; a flying castle with vanishing paths and five extra chests.
- B5: the mermaid village **Seahold** (hints to the boss's random place): **Gilgamesh** (8,888).
  B10: **Atomos** (13,000). B20: **Omega** (35,000) or **Shinryu** (35,000); the Hero's Shield
  behind Shinryu.

### Whisperwind Cove (Wind; after Tiamat; 40 floors; FF6)
- Floors: Cavern of Ice x8 (one with the beaver puzzle), Cavern of Earth x6 (one with dwarves to
  deliver items to), Flying Fortress x4 plus the boss floors, Marsh Cave x4, Giant's Cave x2,
  Mount Gulg x2, Waterfall Cavern x2, a flooded Western Keep, a floating continent, a swamp of
  souls (Astos and the Vampire attack), the fairy kingdom **Feyhome** (fairies heal fully or drop
  HP / MP to 1), five towns (a mage village with every spell and shops; a robot town; a town of
  children with portal doors; two plain towns with inns and shops).
- B10: **Typhon** (10,000). B20: **Orthros** (17,000). B30 (a cursed town first): **Phantom Train**
  (9,999). B40: **Death Gaze** (30,000); the Ultima Weapon behind it. All four in one run.

## 4. Adapting the floors to FF1 (mock-ups 3 and 4)

- Every floor uses FF1's own tileset for the place it imitates, from the user's ROM: Earth Cave,
  Gurgu Volcano, Ice Cave, Marsh Cave, Waterfall Cave, the Sea Shrine, the Temple of Chaos, the
  Floating Castle, Bahamut's caves, towns, castles, the overworld tiles for the desert, forest and
  overworld floors.
- Layouts follow the Dawn of Souls maps tile for tile, redrawn the FF1 way: a floor is FF1's floor
  tile, walls are FF1's one-tile outlines (left / right / top / bottom pieces and corners), the
  black void around. Simple floors convert automatically from the map images (Altar Cave 1 and 2,
  mock-up 3); floors with narrow mazes or rooms (Earthgift B5) are transcribed by hand with a small
  tool.
- **Rooms and doors as on the NES (owner, 2026-11-27):** an area behind a door is an FF1 room:
  the door sits in the corridor's wall, the room is drawn with FF1's room tiles and shows as black
  from the corridor; stepping through the door shows the room and blacks out the rest (mock-up 4,
  copied from Earth Cave B1's room at (38-43, 13-19)). Earthgift's four boss alcoves, Seahold's
  houses, the towns' houses all work this way. The native build already does FF1's rooms.
- Map size: FF1 maps are 64 x 64. Floors larger than that (the desert is 100 x 100 and loops) are
  either cut to 64 x 64 keeping their structure (the desert loops on FF1 anyway: FF1's maps wrap),
  or split (decision D7).
- Count: 80 floor maps (Earthgift 6, Hellfire 13, Lifespring 21, Whisperwind 40).

## 5. Monsters and bosses

- 50 new regular monsters. From their Dawn of Souls sprites, nearly all are recolours of FF1
  monster families (Black Goblin = Goblin, Wild Nakk = Wolf, Skuldier = Skeleton, Sahagin Queen =
  Sahagin, Yellow Ogre / Mad Ogre = Ogre, Rock Gargoyle = Gargoyle, the Gigas = Giants, Mythril
  Golem = Golem, Mage Chimera = Chimera, Pharaoh = Mummy, Yamatano Orochi = Hydra, Poison Naga =
  Naga, Blood Tiger = Sabertooth, Dark Wolf = Wolf, Gloom Widow = Tarantula, ...; to be confirmed
  one by one). They use FF1's own pictures from the user's ROM with new palettes (mock-up 5:
  Black Goblin). Stats (HP, attack, defense, magic, EXP, Gil, elements) from the wiki pages.
- 16 bosses: FF3's four Dark Crystal guardians (Earthgift), FF4's Archfiends (Hellfire), FF5's
  four (Lifespring), FF6's four (Whisperwind). Their art is not in FF1: decision D2.
- Battles in the approved layout; bosses as FF1 shows a fiend (one large picture, their own
  palettes), with FF1's own boss music.

## 6. Items and equipment

Dawn of Souls adds consumables FF1 does not have (Hi-Potion, X-Potion, Ether, Turbo Ether, Dry Ether,
Elixir, Megalixir, Phoenix Down, Remedy, Eye Drops, Echo Grass, the Curtains, the Fangs, the Tonics and
Drinks, the "Plus" stat items, Silver / Golden Apples, Soma Drop) and equipment (Genji Shield,
Hero's Shield, Sage's Surplice, Sage's Mitre, Bard's Tunic, Thief's Gloves, Twist Headband, Tiger
Mask, Feathered Cap, Hermes' Shoes, Kenpogi, Black Cowl, the Ultima Weapon, ...). Decision D4.

## 7. New mechanics (the engine has most of the pieces)

Already in the native build: rooms and doors, damage floors (lava), talk-started battles, vehicles,
shops and inns, chests, teleports. New:
- a run: random floor order from each dungeon's set, chests shuffled from each floor's list, the
  boss floor's portal out, one boss per floor per run, defeat = back to the world map with EXP and
  items kept, cleared bosses remembered in the save;
- floor-specific events: the desert's palm-tree compass, timed damage tiles, roaming NPCs that
  block paths, glittering patches, vanishing paths, the dragon hunt, Seahold's hints, beavers,
  dwarves' deliveries, the robot repair, the child search with portal doors, Feyhome's fairies, the
  swamp of souls, the cursed town;
- a fourth vehicle situation: ship / airship found inside a floor (Hellfire's overworld floors).

## 8. Room, size and performance

- ROM: about 1 MB free (`GBN_SPACE=1 python3 tools/gbn/build.py`). 80 maps at up to 4 KB, ~70
  monsters and 16 boss pictures, items and text fit; the cartridge can also grow to 8 MB.
- Work RAM: nearly full; a floor uses the field's own map memory (as any map). Run state and boss
  flags (a few dozen bytes) go in the save in cart RAM.
- Frame time: floors are ordinary maps, so the 0-lag rule is kept as for FF1's own dungeons; new
  per-frame effects (timed damage tiles, vanishing paths) are measured like every other feature.

## 9. Decisions for the owner

- **D1 Where the Dawn of Souls data lives.** The floor layouts, monster stats, encounter and
  treasure tables come from Dawn of Souls, not from the NES ROM. `CLAUDE.md` says no maps or game
  data in the repository; the Modern MP data was allowed as tool data (`tools/gbn/modern_mp.py`).
  Options: (a) allow these tables and transcribed layouts as tool data in the repository, as
  Modern MP; (b) the builder reads them from the user's own Dawn of Souls GBA ROM (needs its formats
  worked out first: much more work).
- **D2 Boss pictures** (16 bosses from FF3-FF6). Options: (a) Earthgift's four from the user's FF3
  ROM (FF3's own World of Darkness bosses; to be confirmed there), the others from the user's
  FF4 / FF5 / FF6 cartridges or the Dawn of Souls ROM at build time, reduced to Game Boy colours;
  (b) FF1 pictures recoloured as stand-ins; (c) our own drawings (not allowed by the repository
  rules as they stand).
- **D3 Text.** The dungeons need new English text (statues, NPCs, Seahold, Feyhome, towns, the
  defeat message). Options: Dawn of Souls' official wording, or new text in the project's style
  under the translation rules.
- **D4 Items.** Add Dawn of Souls' items as new items (more item slots, menus, effects), or map
  them to FF1's own where one exists and leave the rest out.
- **D5 Music.** FF1's own tracks (dungeon, boss) - nothing else is in the user's ROM.
- **D6 Statues.** Made from FF1's Fiend pictures (mock-up 2), as proposed?
- **D7 Large floors.** Cut to 64 x 64 (FF1's map size) or split.
- **D8 Order.** Earthgift first as the pilot (6 maps, 7 monsters, 4 bosses), then Hellfire,
  Lifespring, Whisperwind.
