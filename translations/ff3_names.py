import sys, os, json
sys.path.insert(0, os.path.dirname(__file__))
from apply import apply
T = {}
W = ['Bare Hands','[64]Kaiser Knuckles','[64]Cat Claw','[64]Wyvern Claw','[64]Fairy Claw','[64]Hell Claw',
 '[64]Nunchaku','[64]Tonfa','[64]Three-Section Staff','[66]Mythril Rod','[66]Flame Rod','[66]Ice Rod',
 '[66]Light Rod','[66]Rod of All','[66]Staff','[66]Burning Staff','[66]Freezing Staff','[66]Shining Staff',
 '[66]Golem Staff','[66]Rune Staff',"[66]Elder's Staff",'[67]Hammer','[67]Thor Hammer','[6A]Battle Axe',
 '[6A]Double Haken','[6A]Morning Star','[68]Thunder Spear','[68]Wind Spear','[68]Blood Lance',
 '[68]Holy Lance','[69]Knife','[69]Dagger','[69]Mythril Knife','[69]Main Gauche','[69]Orichalcum',
 '[69]Air Knife','[6B]Longsword','[6B]Wightslayer','[6B]Glittering Sword','[6B]Mythril Sword',
 '[6B]Serpent Sword','[6B]Freeze Blade','[6B]Tyrfing','[6B]Salamander Sword',"[6B]King's Sword",
 '[6A]Double Tomahawk','[6B]Ancient Sword','[6C]Ashura','[6B]Blood Sword','[6B]Defender',
 '[67]Triton Hammer','[6C]Kotetsu','[6C]Kiku-ichimonji','[6B]Break Blade','[6B]Excalibur','[6C]Masamune',
 '[6B]Ragnarok','[6B]Onion Sword','[65]Book of Flame','[65]Book of Ice','[65]Lexicon of Flame',
 '[65]Book of Light','[65]Lexicon of Light','[70]Boomerang','[70]Full Moon Ring','[71]Shuriken',
 '[65]Lexicon of Ice','[6F]Cut-Glass Bell','[6F]Earth Bell','[6F]Rune Bell','[6D]Harp of Madora',
 '[6D]Harp of Dreams',"[6D]Lamia's Harp","[6D]Loki's Harp",'[6E]Bow','[6E]Great Bow','[6E]Killer Bow',
 '[6E]Rune Bow',"[6E]Yoichi's Bow",'[6E]Wooden Arrows','[6E]Holy Arrows','[6E]Iron Arrows',
 '[6E]Thunder Arrows','[6E]Fire Arrows','[6E]Ice Arrows','[6E]Medusa Arrows',"[6E]Yoichi's Arrows"]
T.update(enumerate(W))
A = ['[60]Leather Shield','[60]Onion Shield','[60]Mythril Shield','[60]Ice Shield',"[60]Hero's Shield",
 "[60]Demon's Shield",'[60]Diamond Shield','[60]Aegis Shield','[60]Genji Shield','[60]Crystal Shield',
 '[62]Leather Cap','[62]Onion Helm','[62]Mythril Helm','[62]Tusk Shell Helm','[62]Ice Helm','[62]Headband',
 "[62]Scholar's Hat",'[62]Black Hood','[62]Chakra Band','[62]Viking Helm','[62]Dragon Helm',
 '[62]Feathered Hat','[62]Diamond Helm','[62]Genji Helm','[62]Crystal Helm','[62]Ribbon',
 '[61]Clothes','[61]Leather Armor','[61]Onion Armor','[61]Mythril Armor','[61]Tusk Shell Armor',
 '[61]Ice Armor','[61]Flame Mail','[61]Kenpo Gi','[61]Black Garb',"[61]Wizard's Garb",'[61]Viking Mail',
 '[61]Black Belt Gi',"[61]Knight's Armor",'[61]Dragon Mail',"[61]Bard's Garb","[61]Scholar's Garb",
 '[61]Robe of the Earth',"[61]Demon's Mail",'[61]Diamond Mail','[61]Reflect Mail','[61]White Robe',
 '[61]Black Robe','[61]Genji Armor','[61]Crystal Mail','[61]Rusty Armor',
 '[63]Copper Bracelet','[63]Onionlet','[63]Mythril Gauntlets','[63]Mythril Bracelet',"[63]Thief's Gauntlets",
 '[63]Gauntlet','[63]Power Wrist','[63]Rune Bracelet','[63]Diamond Bracelet','[63]Diamond Gauntlets',
 '[63]Ring of Protection','[63]Genji Gauntlets','[63]Crystal Gauntlets']
T.update({88 + i: v for i, v in enumerate(A)})
K = ['Magic Key','Gysahl Vegetable',"Dwarf's Horn","Nept's Eye",'Gear of Time','Eureka Key','Fang of Wind',
 'Fang of Fire','Fang of Water','Fang of Earth',"Noah's Lute",'Syrcus Key',"Little People's Bread",
 '?????????','Potion','High Potion','Elixir','Phoenix Tail','Golden Needle',"Maiden's Kiss",'Echo Herb',
 'Lucky Mallet','Eye Drops','Antidote','Sea Otter Head','Bomb Fragment','Antarctic Wind',"Zeus's Wrath",
 "Bomb's Right Arm",'Arctic Wind','Wrath of the Gods','Earth Drum','Lamia Scale',"Bacchus's Wine",
 'Turtle Shell',"Devil's Sigh",'Black Hole','Black Scent',"Lilith's Kiss","Tengu's Yawn",
 'Turtle Shell Cracker','Anesthetic Needle','Charm of Silence','Sheep Pillow',"Bomb's Head",
 'Curtain of Light',"Chocobo's Wrath",'White Scent']
T.update({152 + i: v for i, v in enumerate(K)})
M = ['[75]Flare','[75]Death','[75]Meteor','[74]Tornado','[74]Arise','[74]Holy','[72]Bahamut','[75]Quake',
 '[75]Breakga','[75]Drain','[74]Curaga','[74]Esuna','[74]Reflect','[72]Leviathan','[75]Firaga','[75]Bio',
 '[75]Dejon','[74]Aeroga','[74]Stona','[74]Haste','[72]Catastrophe','[75]Thundaga','[75]Kill','[75]Erase',
 '[74]Curada','[74]Raise','[74]Protes','[72]Hyper','[75]Break','[75]Blizzaga','[75]Shade','[74]Libra',
 '[74]Confuse','[74]Silence','[72]Heatra','[75]Fira','[75]Blizzara','[75]Thundara','[74]Cura',
 '[74]Teleport','[74]Blindna','[72]Spark','[75]Thunder','[75]Poison','[75]Blind','[74]Aero','[74]Toad',
 '[74]Minimum','[72]Icen','[75]Fire','[75]Blizzard','[75]Sleep','[74]Cure','[74]Poisona','[74]Sightro',
 '[72]Escape']
T.update({200 + i: v for i, v in enumerate(M)})
apply('script/ff3/names8800.json', T)

ATK = ['Zantetsuken','Flame','Snowstorm','Thunderbolt','Poison Mist','Earthquake','Glare','Restore 1','Elixir',
 'Tidal Wave','Wave Cannon','Self-Destruct','Glare','Glare','Stinking Breath','Mind Blast','Summoning Magic',
 'Division 1','Megaflare','Defend','Bite','Barrier Change','Multiply','Division 2','Earthquake','Quicksand',
 'Kamaitachi','Bottomless Swamp','Rapids','Whirlpool','Tornado','Avalanche']
MON1 = ['Goblin','Carbuncle','Eye Fang','Blue Wisp','Killer Bee','Werewolf','Berserker','Red Wisp','Dark Eye',
 'Zombie','Mummy','Skeleton','Cursed Copper Coin','Larvae','Shadow','Revenant','Firefly','Dive Eagle',
 'Last Bird','Rukh','Basilisk','Bugbear','Mandrake','Unne Clone','Leprechaun','Dark Face','Petit',
 'Poison Bat','Lilliput','Wererat','Blood Worm','Killer Fish','Hermit','Sea Elemental','Tangy','Sahagin',
 'Paralima','Griffon','Lynx','Hornet','Knocker','Flyer','Lizardman','Gorgon','Red Cap','Barometz','Slime',
 'Tarantula','Kafjel','Pygman','Farjarg','Blood Bat','Petit Mage','Furiae','Ohishuki','Bomb','Manticora',
 'Stalactite','Sea Devil','Merman','Ruinous Wave','Balloon','Myrmecoleo','Crocotta','Adamantaimai',
 'Red Marshmallow','Pharaoh','Lemures','Lamia','Demon','Dullahan','Anet','Mermaid','Sea Horse',
 'Sea Serpent','Cockatrice','Poison Toad','Twin Head','Roper','Agaliarept','Dark Foot','Gigantoad',
 'Twin Liger','Stroper','Black Pudding','Hellcan','Vulcan','Leucrocotta','Magician','Wandering Gold Coin',
 'Gold Eagle','Gold Warrior','Gold Bear','Gold Knight','Nightmare','Hellcan Mage','Needle Monkey',
 'Catoblepas','Sorcerer','Captain','Sandworm','Ice Fly','Phoenix','Simurgh','Harpuia','Gargoyle','Chimera',
 "Devil's Horse",'Rock Gargoyle','Bullman','Black Knight','Mage Flyer']
assert len(ATK) == 32 and len(MON1) == 112, (len(ATK), len(MON1))
T2 = {256 + i: v for i, v in enumerate(ATK)}
T2.update({288 + i: v for i, v in enumerate(MON1)})
apply('script/ff3/names8800.json', T2)

MON2 = ['Nigul','Abtoh','Nept Dragon','Kargra','Charybdis','Deelai','Mage Chimera','King Lizard','Pteranogon',
 'Wyvern','Behemoth','King Sea Horse','Dragon','Kyklops','Boss Troll','Fachan','Kenkos','Balor','Dosmare',
 'Sea Witch','Murder Hermit Crab','Olog-hai','Kelpie','Aegir','Pyralis','Silenus','Garb','Azriel','Eater',
 'Hobgoblin','Dragon Zombie','Death Claw','Horse of Hell','Chronos','Balfrey','Haniel','Bassago','Peryton',
 'Ogre','Cyclops','Nemesis','Humbaba','Death Needle','Liger','Xande Clone','Aion','Minotaur','Ouroboros',
 'Planktai','Sea Lion','Remora','Grenade','Winged Dragon','Great Boros','Liger Saber','Lamia Queen',
 'Iron Claw','Great Demon','Thanatos','Bone Dragon','King Behemoth','Doga Clone','Green Dragon','Abai',
 'Sleipnir','Haokah','Acheron','Oceanus','Amon','Gomory','Burak','Flame Demon','Platinal','Kumkum',
 'Shinobi','Chief','Shade','Dark General','Spriggan','Terrible Dragon','Glasya-Labolas','Jormungand','Thor',
 'Hecatoncheir','Hydra','Queen Scylla','Garm','Double Dragon','Yellow Dragon','Bahamut','Odin','Leviathan',
 'Land Turtle','Djinn','Giant Rat','Medusa','Gutsco the Thief','Salamander','Hein the Wizard','Kraken',
 'Goldor','Garuda','Bahamut','Doga','Unne','Titan','Ninja','Kunoichi','General','Scylla','Guardian',
 'Red Dragon','Demon King Xande','Cerberus','Two-Headed Dragon','Echidna','Ahriman','Cloud of Darkness',
 'Cloud of Darkness']
assert len(MON2) == 119, len(MON2)
T3 = {400 + i: v for i, v in enumerate(MON2)}
for base, name in ((519,'Chocobo'),(522,'Shiva'),(525,'Ramuh'),(528,'Ifrit'),(531,'Titan'),(534,'Odin'),(537,'Leviathan')):
    T3[base] = '[74]' + name; T3[base+1] = '[75]' + name; T3[base+2] = name
apply('script/ff3/names8800.json', T3)

MSG = {
 540:'[74]Bahamut', 541:'[75]Bahamut', 542:'Bahamut',
 545:'Absorbed the magic!', 546:'Forward', 547:'Back', 548:'Fight', 549:'Defend', 550:'Run',
 551:'Bolt', 552:'Jump', 553:'Miss!', 554:'Sure Kill', 555:'Terrain', 556:'Examine', 557:'See Through',
 558:'Steal', 559:'Build Up', 560:'Sing', 561:'Scare', 562:'Cheer', 563:' hits', 564:'Item', 565:'Magic',
 566:'All', 567:'First strike!', 568:'The monsters strike first!', 569:'Back attack!', 570:'has died!',
 571:'Defeated the enemy!', 572:'Wiped out...', 573:'The enemies were wiped out!', 574:'Ran away...',
 575:"Can't escape!", 576:'Level up!', 577:'Stopped its breath for good!', 578:'Proficiency up!',
 579:'Near death', 580:'Fully revived!!', 581:' [77][79] absorbed!', 582:' [77][79] was drained!',
 583:' [77][79] was drained back instead!!', 584:'Turned to stone and crumbled away!', 585:'Treasure:',
 586:' [77][79] restored!', 587:'Status restored', 588:'Put up a barrier', 589:' Gil obtained!',
 590:' Capacity gained!', 591:'Built up too much and self-destructed!',
 592:'Sent into the rift between dimensions!', 593:'Everyone is fired up!', 594:'Frightened the monsters',
 595:'Attack power up!', 596:'Critical hit!', 597:'Failed to steal', 598:'The small fry were wiped out!',
 599:'Barrier removed!', 600:' [77][79] restored!', 601:'Came back to life!', 602:'Defense up!',
 603:'It had no effect', 604:'The body is slowly turning to stone', 605:'Covering fire from the cannon!',
 606:"Bound the enemy's shadow", 608:' points of [76][7A][79] gained', 609:'Poison damage!',
 610:"Can't sing without a harp!", 611:'No particular weakness', 612:'Is watching and waiting',
 613:'Damage to the undead!', 614:' [77][79] restored!', 615:'Sent into the rift between dimensions!',
 616:'Weak against holy power!', 617:'Weak against earthquakes!', 618:'Weak against the power of wind!',
 619:'Weak against fire!', 620:'Weak against cold!', 621:'Weak against lightning!',
 622:'Weak against the Dark Sword!', 623:'Failed! The damage came back!',
 624:'Silenced, so it has no effect!', 625:'Nothing happened',
 626:'The Knight threw their body in the way and covered!', 627:"Frogs can't use magic!",
 628:' [77][79] restored!', 629:"Was ready to run and couldn't defend", 630:'It meant nothing during battle!',
 639:' [77][79] restored!', 640:'[77][79]/[78][79] fully restored!', 643:'Dealt damage and self-destructed!',
 648:'Summoned a monster!', 649:'Split apart!', 651:'Pulled its head in and is protecting itself',
 652:'Stuck its head out and attacked', 653:'Its weakness changed!', 654:'Called its friends and multiplied!',
 655:'Split apart!', 656:'Caused an earthquake!', 657:'Stepped into quicksand', 658:'Vacuum Kamaitachi!',
 659:'Sank into a bottomless swamp', 660:'Swallowed by the rapids', 661:'A whirlpool engulfs the enemy!',
 662:'Called a tornado!', 663:'Falling rocks hit the enemy head-on!', 664:'Scampered off',
 665:'Got punched!', 666:'Kick', 667:'Hypnotic beam!', 668:'Frozen solid by an icy stare',
 669:'Diamond Dust!', 670:'Mind Blast!', 671:'Lightning of the Gods', 672:'Wrath of Heaven',
 673:'Healing magic', 674:'Flames of Wrath', 675:'Flames of Hell', 676:'Beat it to a pulp',
 677:'Laid in kick after kick', 678:'Shakes the earth!', 679:'Barrier on everyone!',
 680:'The sword cut the enemy apart!', 681:'Zantetsuken! The enemies were wiped out!',
 682:'Petrifying glare!', 683:'Raised a giant tornado', 684:'Raised a tsunami',
 685:'Aura! Attack power up', 686:'Cut it clean in two!', 687:'Megaflare!',
}
apply('script/ff3/names8800.json', MSG)

# items without an icon: the Japanese names open with a space in the icon's cell (lists keep
# their column, and the unusable mark goes there); the English keep it
rows = json.load(open('script/ff3/names8800.json'))
SP = {e['id']: ' ' + e['en'] for e in rows if e['id'] < 256 and e['ja'] and e['ja'].startswith('　')
      and e['en'] and not e['en'].startswith(' ')}
apply('script/ff3/names8800.json', SP)
