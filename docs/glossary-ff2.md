# Final Fantasy II — glossary and translation notes

All renderings are from the Japanese. `{18:xx}` inserts entry xx of `script/ff2/names.json`.

## People
| Japanese | English | Note |
|---|---|---|
| ヒルダ | Hilda | princess of Finn (`{18:EF}`, "Princess" = `{18:ED}`) |
| ゴードン | Gordon | prince of Kashuon (`{18:EB}`) |
| スコット | Scott | his elder brother |
| ミンウ / ヨーゼフ / レイラ / リチャード | Minwu / Josef / Leila / Richard | guests (`guest_names.json`) |
| リチャード ハイウィンド | Richard Highwind | Dragon Knight |
| シド | Cid | airship owner; シドのこぶん = "Cid's Henchman" |
| ポール | Paul | thief |
| トブール (ドブール in two lines) | Tobul (Dobul) | blacksmith; the Japanese itself misspells him as ドブール twice, kept as "Dobul" |
| ネリー | Nelly | Josef's daughter |
| エリナ / フィリップ | Elina / Philip | Dragon Knight's widow / her husband |
| ハーン | Hahn | first Dragon Knight |
| ボーゲン | Bogen | count, traitor |
| こうてい | Emperor (`{18:F0}`) | |
| ダークナイト | Dark Knight (`{18:EE}`) | |
| わたし | I (`{18:EC}`) | inserted pronoun; sentences are built so "I" reads as a subject. Where English needs the object or possessive form, the word is written out ("me", "my") instead of the insert, which can only print "I". Twice the Japanese uses it as the first syllables of わたして/わたしたい ("hand over"); English keeps the insert as "I" |

## Places
フィン Finn · アルテア Altea · ガテア Gatea · パルム Palm · ポフト Poft · バフスク Bafsk ·
サラマンド Salamand · セミテのたき Semite Falls · カシュオーン Kashuon · ディスト Deist ·
ミシディア Mysidia · パラメキア Palamecia · パンデモニウム Pandaemonium · ジェイドのうみ Sea of Jade ·
せつげん the snowfield · とうぎじょう the Coliseum · まかい the Demon World

## Things
だいせんかん Great Battleship · ひくうせん Airship · たつまき Tornado (the Emperor's cyclone) ·
のばら Wild Rose (password and crest) · たいようのほのお Sunfire · エギルのたいまつ Egil's Torch ·
めがみのベル Goddess's Bell · ひりゅう Wyvern · りゅうきし Dragon Knight · フェニックスのお Phoenix Tail ·
アダマンタイマイ Adamantaimai (adamant + taimai, the hawksbill turtle) · クアール Coeurl · ベルゼブル Beelzebul

## Style
- Guy (`{12:02}`) speaks in broken Japanese; rendered as broken English ("Me understand animal talk").
- Leila, the pirates and Paul speak roughly (あたい, ～だぜ); kept rough.
- Learnable key words appear in brackets: `[{16:xx}{18:yy}]` → "[Wild Rose]".
- The Emperor's death scream ウボァー is kept as "UBOAAAH".
- Name-entry grid (`system.json` #70) is replaced by a Latin letter grid with the same layout codes.
- Shop command ことわる (decline the shopkeeper's offer) is "Pass": the shop's command window shows five letters while the sell list overlaps it.
- りゅうさんのビン is "Sulfuric Acid Bottle" (20 letters, the widest list width).
- Battle command もちもの (what a character holds: the two hands' weapons and the items) is "Gear": the
  command window shows five letters (the screen scrolls just far enough for it).
- たずねる / おぼえる / アイテム (key-word menu) start one column further left (the hand on the border), so
  "Learn" and "Items" fit beside the key-word window.
- Status words (battle status window: the maximum-HP slot plus the blank cell after it, 5 cells):
  どく Poison · ねむり Sleep · ちんもく Silence · こびと Tiny · まひ Paralysis · こんらん Confusion ·
  もうもく Blind · もうどく Venom (the virulent poison) · のろい Curse · わすれた Forgot · かえる Frog ·
  いし Stone · しぼう Dead. Poison, Silence, Forgot, Paralysis and Confusion are drawn on five tiles
  of their own (the last two in condensed letters).
- のレベルがあがった (appended to a spell or weapon type) is " level went up" ("Sword level went up",
  "Bare Hands level went up").
