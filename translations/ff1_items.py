import sys, os, json
sys.path.insert(0, os.path.dirname(__file__))
from apply import apply
T = {
 # key items
 1:'Lute', 2:'Crown', 3:'Crystal Eye', 4:'Waking Medicine', 5:'Mystic Key', 6:'Nitro Powder',
 7:'Adamantite', 8:'Rosetta Stone', 9:'Star Ruby', 10:'Staff of Earth', 11:'Floating Stone',
 12:'Chime', 13:"Rat's Tail", 14:'Warp Cube', 15:'Fairy Bottle', 16:'Water of Air', 17:'Canoe',
 # 18-21: single kana く/り/す/た (spell クリスタ...), see glossary note; kept as letters
 18:'C', 19:'R', 20:'Y', 21:'S',
 # consumables
 22:'Sleeping Bag', 23:'Tent', 24:'Cottage', 25:'Potion', 26:'Antidote', 27:'Golden Needle',
 # weapons
 28:'Nunchaku', 29:'Knife', 30:'Staff', 31:'Rapier', 32:'Hammer', 33:'Broad Sword', 34:'Battle Axe',
 35:'Scimitar', 36:'Iron Nunchaku', 37:'Dagger', 38:'Ringed Staff', 39:'Saber', 40:'Longsword',
 41:'Great Axe', 42:'Falchion', 43:'Mythril Knife', 44:'Mythril Sword', 45:'Mythril Hammer',
 46:'Mythril Axe', 47:'Flame Sword', 48:'Icebrand', 49:'Wyrmkiller', 50:'Great Sword', 51:'Sun Blade',
 52:'Coral Sword', 53:'Werebuster', 54:'Rune Blade', 55:'Staff of Power', 56:'Light Axe',
 57:'Staff of Healing', 58:'Staff of Sorcery', 59:'Defender', 60:"Wizard's Staff", 61:'Sharp Sword',
 62:'Cat Claw', 63:'Thor Hammer', 64:'Raise Saber', 65:"Sasuke's Katana", 66:'Excalibur', 67:'Masamune',
 # armor
 68:'Clothes', 69:'Leather Armor', 70:'Chain Mail', 71:'Iron Armor', 72:"Knight's Armor",
 73:'Mythril Mail', 74:'Flame Mail', 75:'Ice Armor', 76:'Diamond Armor', 77:'Dragon Mail',
 78:'Copper Bracelet', 79:'Silver Bracelet', 80:'Ruby Bracelet', 81:'Diamond Bracelet',
 82:'White Robe', 83:'Black Robe', 84:'Leather Shield', 85:'Iron Shield', 86:'Mythril Shield',
 87:'Flame Shield', 88:'Ice Shield', 89:'Diamond Shield', 90:'Aegis Shield', 91:'Buckler',
 92:'Protect Cape', 93:'Leather Cap', 94:'Helmet', 95:'Great Helm', 96:'Mythril Helm',
 97:'Diamond Helm', 98:'Helm of Healing', 99:'Ribbon', 100:'Leather Gloves', 101:'Bronze Gauntlets',
 102:'Steel Gauntlets', 103:'Mythril Gauntlets', 104:'Gauntlet', 105:"Giant's Gauntlets",
 106:'Diamond Gauntlets', 107:'Protect Ring',
 # magic (tiers keep the Japanese coinage; 4-kana clippings expanded)
 176:'Cure', 177:'Dia', 178:'Protes', 179:'Blink', 180:'Fire', 181:'Sleep', 182:'Shape', 183:'Thunder',
 184:'Blindna', 185:'Silence', 186:'Thunder Barrier', 187:'Invisible', 188:'Blizzard', 189:'Darkness',
 190:'Strike', 191:'Slow', 192:'Cura', 193:'Adia', 194:'Fire Barrier', 195:'Heal', 196:'Fira', 197:'Hold',
 198:'Thundara', 199:'Shapera', 200:'Poisona', 201:'Fear', 202:'Cold Barrier', 203:'Vocal', 204:'Sleepra',
 205:'Haste', 206:'Confuse', 207:'Blizzara', 208:'Curada', 209:'Raise', 210:'Dadia', 211:'Heala',
 212:'Firaga', 213:'Clouda', 214:'Teleport', 215:'Raslow', 216:'Stona', 217:'Escape Teleport', 218:'Protea',
 219:'Invisia', 220:'Thundaga', 221:'Death', 222:'Quake', 223:'Stun', 224:'Curaga', 225:'Gadia',
 226:'Magic Barrier', 227:'Raheala', 228:'Blizzaga', 229:'Break', 230:'Saber', 231:'Blind', 232:'Arise',
 233:'Holy', 234:'All Barrier', 235:'Dispel', 236:'Flare', 237:'Stop', 238:'Dejon', 239:'Kill',
 # classes: まじゅつし (魔術師) -> Magician, upgraded まどうし (魔導師) -> Wizard
 240:'Warrior', 241:'Thief', 242:'Monk', 243:'Red Magician', 244:'White Magician', 245:'Black Magician',
 246:'Knight', 247:'Ninja', 248:'Super Monk', 249:'Red Wizard', 250:'White Wizard', 251:'Black Wizard',
 # status
 252:'HP', 254:'Stone', 255:'Poison',
}
rows = json.load(open('script/ff1/items.json'))
for e in rows:   # prices: "10ギル" -> "10 Gil"
    j = e['ja'].strip('　')
    if j.endswith('ギル') and j[:-2].isdigit(): T[e['id']] = j[:-2] + ' Gil'
apply('script/ff1/items.json', T)
