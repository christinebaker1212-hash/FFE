import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from apply import apply
SPELLS = ['Fire','Thunder','Blizzard','Clouda','Drain','Aspir','Flare','Sleep','Stun','Stop','Confuse',
 'Blind','Curse','Toad','Break','Death','Dejon','Berserk','Haste','Aura','Cure','Raise','Basuna',
 'Esuna','Barrier','Blink','Protes','Shell','Wall','Dispel','Minimum','Silence','Anti','Fog','Slow',
 'Change','Fear','Holy','Teleport','Ultima']
T = {
 1:'Ring', 2:'Canoe', 3:'Pass', 4:'Mythril', 5:'Snowcraft', 6:"Goddess's Bell", 7:"Egil's Torch",
 8:'Sunfire', 9:'Pendant', 10:'Wyvern Egg', 11:'White Mask', 12:'Black Mask', 13:'Crystal Rod',
 14:'Wyvern', 15:'????', 16:'Potion', 17:'Antidote', 18:'Golden Needle', 19:'Cross', 20:"Maiden's Kiss",
 21:'Mallet', 22:'Eye Drops', 23:'Phoenix Tail', 24:'Elixir', 25:'Ether', 26:'High Potion', 27:'Cottage',
 28:'Wind Flute', 29:'Earth Drum', 30:'Garlic', 31:'Unicorn Horn', 32:'Antarctic Wind', 33:"Sage's Wisdom",
 34:"Saint's Heart", 35:'Hermes Shoes', 36:'Spider Silk', 37:'Bell of Silence', 38:'Hourglass',
 39:"Reaper's Statue", 40:"Bacchus's Wine", 41:'Sulfuric Acid Bottle', 42:'Sleep Grass', 43:'Chill Shell',
 44:'Fang of Betrayal', 45:'Mythril Mirror', 46:'Hellfire', 47:'Finn',
 48:'[6E]Bare Hands', 49:'[6F]Buckler', 50:'[6F]Bronze Shield', 51:'[6F]Mythril Shield', 52:'[6F]Golden Shield',
 53:'[6F]Ice Shield', 54:'[6F]Flame Shield', 55:'[6F]Diamond Shield', 56:'[6F]Dragon Shield', 57:'[6F]Aegis Shield',
 58:'[70]Knife', 59:'[70]Dagger', 60:'[70]Mythril Knife', 61:'[70]Main Gauche', 62:'[70]Orichalcum',
 63:'[70]Ripper Knife', 64:'[70]Cat Claw', 65:'[71]Staff', 66:'[71]Mace', 67:'[71]Mythril Mace',
 68:'[71]Werebuster', 69:'[71]Staff of Sorcery', 70:'[71]Staff of Power', 71:"[71]Wizard's Staff",
 72:'[71]Staff of Healing', 73:'[71]Diamond Mace', 74:'[72]Javelin', 75:'[72]Spear', 76:'[72]Mythril Spear',
 77:'[72]Trident', 78:'[72]Demon Spear', 79:'[72]Flame Spear', 80:'[72]Ice Lance', 81:'[72]Thunder Spear',
 82:'[72]Holy Lance', 83:'[73]Broadsword', 84:'[73]Longsword', 85:'[73]Mythril Sword', 86:'[73]Ancient Sword',
 87:'[73]Sword of Sleep', 88:'[73]Wing Sword', 89:'[73]Blood Sword', 90:'[73]Sword of the Earth',
 91:'[73]Flame Sword', 92:'[73]Icebrand', 93:'[73]Defender', 94:'[73]Sun Blade', 95:'[73]Excalibur',
 96:'[73]Masamune', 97:'[74]Axe', 98:'[74]Battle Axe', 99:'[74]Mythril Axe', 100:'[74]Demon Axe',
 101:'[74]Ogre Killer', 102:'[74]Poison Axe', 103:'[74]Rune Axe', 104:'[75]Bow', 105:'[75]Longbow',
 106:'[75]Mythril Bow', 107:'[75]Bow of Blindness', 108:'[75]Flame Bow', 109:'[75]Ice Bow',
 110:'[75]Killer Bow', 111:"[75]Yoichi's Bow",
 112:'Leather Cap', 113:'Bronze Helm', 114:'Mythril Helm', 115:"Giant's Helm", 116:'Flame Helm',
 117:'Diamond Helm', 118:'Genji Helm', 119:'Twisted Headband', 120:'Golden Hairpin', 121:'Ribbon',
 122:'Clothes', 123:'Leather Armor', 124:'Bronze Armor', 125:'Mythril Armor', 126:'Golden Armor',
 127:"Knight's Armor", 128:'Flame Armor', 129:'Ice Armor', 130:'Diamond Armor', 131:'Dragon Armor',
 132:'Genji Armor', 133:'Copper Breastplate', 134:'Silver Breastplate', 135:'Ruby Breastplate',
 136:'Golden Breastplate', 137:'Diamond Breastplate', 138:'White Robe', 139:'Black Robe',
 140:'Sash of Strength', 141:'Black Garb', 142:'Leather Gloves', 143:'Bronze Gauntlets',
 144:'Mythril Gauntlets', 145:"Thief's Gauntlets", 146:"Giant's Gauntlets", 147:'Ice Gauntlets',
 148:'Diamond Gauntlets', 149:'Genji Gauntlets', 150:'Ring of Protection', 151:'Power Wrist',
 232:'.. Treasure ..', 233:'Drop', 234:'Done',
 # inserted into dialogue with {18:xx} (0xEB-0xFF)
 235:'Gordon', 236:'I', 237:'Princess', 238:'Dark Knight', 239:'Hilda', 240:'Emperor', 241:'Wild Rose',
 242:'Mythril', 243:'Great Battleship', 244:'Palamecia', 245:'Airship', 246:"Goddess's Bell",
 247:'Sunfire', 248:'Mysidia', 249:'Book of Ultima', 250:'Dragon Knight', 251:'Wyvern', 252:'Tornado',
 253:'Jade', 254:'Mask', 255:'Ekmetoteroes',
}
for i, sp in enumerate(SPELLS):
    T[152 + i] = 'Book of ' + sp
    T[192 + i] = sp
apply('script/ff2/names.json', T)
