import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from apply import apply
M = ['Leg Eater','Vampire Thorn','Hornet','Queen Bee','Snowman','Sasquatch','Icicle','Stalactite','Column',
 'Splinter','Big Bird','Adamantaimai','Land Turtle','Ogre','Ogre Mage','Ogre Chief','Dual Head',
 'Zombie Two-Head','Wererat','Stunner','Dead Head','Skull','Zombie','Ghoul','Ghast','Revenant','Shadow',
 'Wraith','Specter','Ghost','Antlion','Murder Saw','Goatus','Beast Demon','Chimera','Gorgimaira',
 'Sphinxmaira','Death Flower',"Devil's Flower",'Killer Fish','Electric Fish','Dive Eagle','Cockatrice',
 'Pirate','Buccaneer','Bogen','Zombie Bogen','Big Horn','Tusk Rhino','Poison Toad','Gigantoad','Sea Snake',
 'Sea Dragon','Land Ray','Manta Ray','Flying Ray','Changer','Brain','Parasite','Mega Parasite','Werewolf',
 'Wolf Devil','Imp','Pit Fiend','Molbol','Land Molbol','Molbol Great','Basilisk','Salamander','Ice Lizard',
 'Eyemoeba','Hecteyes','Roundworm','Sandworm','Abyss Worm','Green Slime','Yellow Jelly','Red Marshmallow',
 'Black Pudding','Red Soul','Green Soul','Yellow Soul','Vampire Girl','Vampire Lady','Emperor',
 "Emperor's Curse",'Killer Mantis','Mantis King','Mantis Devil','Imperial Guard','Black Knight',
 'Death Rider','Wood Golem','Stone Golem','Mythril Golem','Goblin','Goblin Guard','Goblin Prince',
 'Balloon','Grenade','Mine','Bomb','Soldier','Sergeant','Captain','General','Magician','Sorcerer','Wizard',
 'Werepanther','Coeurl','Lamia','Lamia Queen','Hill Gigas','Fire Gigas','Ice Gigas','Thunder Gigas',
 'Behemoth','King Behemoth','White Dragon','Green Dragon','Blue Dragon','Red Dragon','Iron Giant',
 'Tiamat','Beelzebul','Astaroth','Emperor']
assert len(M) == 128
apply('script/ff2/monsters.json', dict(enumerate(M)))
B = ['Fire','Thunder','Blizzard','Clouda','Drain','Aspir','Flare','Sleep','Stun','Stop','Confuse','Blind',
 'Curse','Toad','Break','Death','Dejon','Berserk','Haste','Aura','Cure','Raise','Basuna','Esuna','Barrier',
 'Blink','Protes','Shell','Wall','Dispel','Minimum','Silence','Anti','Fog','Slow','Change','Fear','Holy',
 'Teleport','Ultima','Restore','Eye Drops','Antidote','Cross','Mallet','Kiss','Golden Needle','Revival',
 'Ether','Elixir','Ability','Ability','Liquor','Flame','Snowstorm','Lightning','Poison Mist',
 'Stinking Breath','Glare','Temptation','Self-Destruct','Division','Earthquake','Tornado','Tidal Wave',
 'Garlic','Bow','Rocks','Blaster','Meteorite']
assert len(B) == 70
apply('script/ff2/battle_magic.json', dict(enumerate(B)))
apply('script/ff2/guest_names.json', dict(enumerate(['Minwu','Josef','Gordon','Leila','Richard'])))
