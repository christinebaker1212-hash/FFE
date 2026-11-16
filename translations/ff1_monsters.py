import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from apply import apply
M = ['Goblin','Goblin Guard','Wolf','Warg Wolf','Werewolf','Winter Wolf','Lizard','Fire Lizard',
 'Basilisk','Hill Gigas','Ice Gigas','Fire Gigas','Sahagin','Sahagin Chief','Sahagin Prince',
 'Pirate','Pirates','Shark','White Shark','Big Eye','Deep Eye','Skeleton','Bloody Bone','Gigas Worm',
 'Crawler','Hyenadon','Hellhound','Ogre','Ogre Chief','Ogre Mage','Cobra','Anaconda','Sea Snake',
 'Scorpion','Sea Scorpion','Minotaur','Minotaur Zombie','Troll','Sea Troll','Shadow','Wraith','Specter',
 'Ghost','Zombie','Ghoul','Ghast','Wight','Purple Worm','Sandworm','Lava Worm','Beholder',
 'Death Beholder','Medusa','Earth Medusa','Weretiger','Rakshasa','Ankheg','Remorhaz','Kitty Tiger',
 'Saber Tiger','Vampire','Vampire Lord','Gargoyle','Horned Devil','Earth Element','Fire','White Dragon',
 'Red Dragon','Dragon Zombie','Green Slime','Gray Ooze','Ochre Jelly','Black Pudding','Black Widow',
 'Tarantula','Manticore','Sphinx','Bulette','Desert Bulette','Mummy','King Mummy','Cockatrice',
 'Pyrolisk','Wyvern','Wyrm','Allosaurus','Tyrannosaurus','Piranha','Red Piranha','Crocodile',
 'White Dile','Ochu','Neochu','Hydra','Fire Hydra','Guardian','Soldier','Water','Air Elemental',
 'Water Naga','Spirit Naga','Chimera','Gochimera','Piscodemon','Mind Flayer','Garland','Green Dragon',
 'Blue Dragon','Clay Golem','Stone Golem','Iron Golem','Black Knight','Death Knight','Astos',
 'Dark Wizard','Dark Fighter','Crazy Horse','Nightmare','Death Machine','Lich','Lich','Marilith',
 'Marilith','Kraken','Kraken','Tiamat','Tiamat','Chaos']
assert len(M) == 128
apply('script/ff1/monsters.json', dict(enumerate(M)))
ATK = {'ふぶき':'Snowstorm','ほのお':'Flame','にらみ':'Glare','フラッシュ':'Flash','じしん':'Earthquake',
 'どくガス':'Poison Gas','マインドブラスト':'Mind Blast','いなずま':'Lightning','はないき':'Snort',
 'かくこうげき':'Nuclear Attack','スミ':'Ink','どくばり':'Poison Sting','つなみ':'Tidal Wave','たつまき':'Tornado'}
import json
rows = json.load(open('script/ff1/enemy_attacks.json'))
apply('script/ff1/enemy_attacks.json', {e['id']: ATK[e['ja']] for e in rows})
