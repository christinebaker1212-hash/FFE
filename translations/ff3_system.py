"""FF3 table B ($8200): system messages, shops, menus, places, jobs, characters."""
import json, re, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from apply import apply

P = 'script/ff3/t8200.json'
rows = json.load(open(P))
def codes_only(i):            # entries with no text: copy layout codes, full-width space -> space
    return rows[i]['ja'].replace('　', ' ')

T = {
 1: ' From inside the treasure chest\n you got {03} Gil!',
 2: ' Inside the treasure chest\n there was {02}!\n Suddenly, monsters appeared!!',
 3: ' The door is locked!',
 4: ' Innkeeper: "Welcome! To restore your party\'s [77][79]\n   it will cost {04} Gil.\n   Will you stay the night?"',
 5: '{05}{14:08}Gil',
 6: '{15:01}Yes\n{15:01}No',
 7: ' Weapon Shop', 8: ' Armor Shop', 9: ' Item Shop', 10: ' Magic Shop',
 11: '{15:01}Buy{15:05}Sell{15:09}Exit',
 12: 'Revived', 13: 'Stone cured', 14: 'Paralysis wore off', 15: 'Woke from sleep',
 16: 'Came back to their senses', 17: 'Back to normal', 18: 'Silence cured', 19: 'Grew big again',
 20: 'Can see again!', 21: 'The poison is gone',
 22: 'Death', 23: 'Stone', 24: 'Paralysis', 25: 'Sleep', 26: 'Confusion', 27: 'Frog',
 28: 'Silence', 29: 'Mini', 30: 'Blind', 31: 'Poison',
 34: '{15:01}New Game',
 35: 'Message Speed {06}',
 36: '{15:01}Deposit{15:07}Withdraw{15:0D}Exit',
 38: 'Welcome. What business brings you here?',
 39: 'What would you like?',
 40: 'Thank you very much. Anything else?',
 41: 'Thank you for your patronage.',
 42: 'What will you sell?',
 43: 'Then that comes to {04} Gil.',
 44: "You're carrying too much to buy any more.",
 45: ' How many?{15:06}1{15:08}4{15:0A}10',
 46: ' How many?{15:06}1{15:08}All',
 49: '{15:01}Item\n{15:01}Magic\n{15:01}Equip\n{15:01}[E1][E2][E3][E4]\n{15:01}Order\n{15:01}Job\n{15:01}Save',
 53: ' Item',
 54: ' {10:02}{15:09}Use{15:0F}Exchange{15:16}Item',
 55: ' Status', 56: ' Save',
 58: " To change to this job, it seems you don't\n have enough experience.",
 62: ' {10:02}{14:0A}Attack..{10:33}{14:13}Defense..{10:34}\n{15:01}{10:06}{10:43}{15:12}{10:03}\n{15:01}{10:07}{10:44}{15:12}{10:04}\n{15:01}Remove Equipment{15:12}{10:05}',
 63: 'Effect.. Strength rose by 5!', 64: 'Effect.. Agility rose by 5!',
 65: 'Effect.. Stamina rose by 5!', 66: 'Effect.. Intelligence rose by 5!',
 67: 'Effect.. Spirit rose by 5!', 68: 'Effect.. Fire magic power up!',
 69: 'Effect.. Cold magic power up!', 70: 'Effect.. Lightning magic power up!',
 71: '{14:0C}{10:02}{14:14}{10:01}\n{14:12}Proficiency {10:3D}\n  [5E][76][5F][76][5E] {10:3E}{14:0E}[76][7A][79] {10:32}\n'
     '{14:0A}To next level {10:FF}\n [77][79] {10:30}/{10:31}\n'
     ' [78][79] {10:80}/{10:81}/{10:82}/{10:83}/{10:84}/{10:85}/{10:86}/{10:87}\n\n'
     '  Strength     .. {10:38}{14:0D}Attack {10:46} times..{10:33}\n'
     '  Agility      .. {10:39}{14:0D}Hit rate{14:15}.. {10:42}\n'
     '  Stamina      .. {10:3A}{14:0D}Defense {10:47} times..{10:34}\n'
     '  Intelligence .. {10:3B}{14:0D}Evasion rate{14:15}.. {10:41}\n'
     '  Spirit       .. {10:3C}{14:0D}Magic defense{14:15}..{10:36}\n'
     '{14:0D}Magic evasion rate.. {10:40}',
 75: 'Please choose the file to save to.',
 76: 'This will erase the previous data.{15:0E}Yes{15:12}No',
 77: 'Saving is complete.',
 78: 'Hold in RESET while you turn the power off.',
 79: 'Thank you very much. Please rest well...',
 80: 'Your inventory is full.',
 81: 'Fat Chocobo: "Yooo, need somethiiing?"',
 82: '"Whatcha gonna give meee?"',
 83: '"Whaddaya want, ya saaay?"',
 84: '"Time to diiig in. Munch munch..."',
 85: '"I can\'t eat no more of the same stuff, ya know"',
 86: '"Your stuff\'s full, so I can\'t give it back, huh"',
 87: '"I can\'t give it all back, so I\'ll hang on to the rest"',
 88: '"Hang on a sec, I\'m gettin\' it out now..."',
 89: ' Inside the treasure chest\n there was {02}!',
 90: "It can't be used.",
 91: 'Whose [77][79] will you restore?', 92: 'Whose [77][79] will you restore?',
 93: 'Whom will you fully restore?', 94: 'Whom will you bring back to life?',
 95: 'Cures the state of stone', 96: 'Turns someone who became a frog back to normal',
 97: 'Cures silence', 98: 'Makes small, or returns to normal', 99: 'Restores eyesight',
 100: 'Whose poison will you cure?', 101: 'Warps outside',
 102: 'Whose status will you cure?', 103: 'Go back how many floors? ',
 104: 'Warps outside',
 105: 'Turns into a frog, or back again One/All',
 106: 'Makes small, or returns to normal One/All',
 107: "Your inventory is full, so you can't remove it.",
 108: "You don't have enough money.",
 110: ' Removed the equipment.', 111: " Can't equip.",
 112: '    Change jobs?\n   A..Yes  B..No',
 113: " You can't change jobs unless you remove all\n your equipment.",
 114: '     Not enough Capacity!',
 115: 'Who will hold this magic?', 116: "Can't hold any more.",
 117: 'Already holds this magic.',
 118: ' {02} in a place like this!',
 119: " It's too cramped to become big.",
 120: ' Warping impossible', 121: ' Magic cannot be used',
 122: " With the Thief's special ability\n the lock opened just like that!",
}
PLACES = {
 124:'Ur', 125:'Kazus', 126:'Canaan', 127:'Tozus', 128:'Tokkul', 129:'Village of the Ancients',
 130:'Gysahl', 131:'Amur', 132:'Duster', 133:'Replito', 134:'Saronia, Part 1',
 135:'Ancient Ruins Survey Team', 136:'Falgabard', 137:'Sasune Castle', 138:'Argus Castle',
 139:'Saronia Castle', 140:'Cave of the Dwarves', 141:"Vikings' Hideout",
 142:'Valley of the Gulgan Tribe', 143:'Sasune Left Tower', 144:'Sasune Right Tower',
 145:'Argus Left Tower', 146:'Argus Right Tower', 147:'Hall of the Round Table',
 148:'Path to the Summit', 149:'Chocobo Forest', 150:'Living Forest', 151:"Bahamut's Nest",
 152:"Cid's Airship", 153:'Temple of Nept', 154:'Mythril Mine', 155:'Well of Ur',
 156:'Sealed Cave', 157:'Cave of Flame', 158:'Altar Cave', 159:'Saronia, Part 2',
 160:'Saronia, Part 3', 161:'Saronia, Part 4', 162:'Saronia Battlefield',
 163:'Underground Lake', 164:'Tozus Back Passage', 165:'Tower of Owen', 166:"Hein's Castle",
 167:'Falgabard Cave', 168:'Crystal of Wind', 169:'Crystal of Fire', 170:'Lake Dohr',
 171:"Bahamut's Cave", 172:"Doga's Manor", 173:"Unne's Shrine", 174:'Shipwreck',
 175:'Temple of Water', 176:'Cave of Water', 177:'Sewer', 178:"Goldor's Manor",
 179:'Cave of the Magic Circle', 180:"Doga's Cave", 181:'Temple of Time', 182:'Undersea Cave',
 183:'Behind the Waterfall', 184:'Cave of Darkness', 185:'Ancient Ruins',
 186:'Great Ship Invincible', 187:'Labyrinth of the Ancient People', 188:'Crystal Tower',
 189:"Xande's Chamber", 190:'World of Darkness', 191:'Basement Floor 1',
 192:'Crystal of Water', 193:'Crystal of Earth', 194:'Dark Crystal of Wind',
 195:'Dark Crystal of Fire', 196:'Dark Crystal of Water', 197:'Dark Crystal of Earth',
 198:'Saronia Underground Maze', 199:'Forbidden Land Eureka',
 216:'Floor 1', 217:'Saronia Library', 218:'Village of Doga', 219:'Forest of Healing',
 220:"King of Sasune's Chamber",
}
for n in range(2, 9): PLACES[198 + n] = 'Basement Floor %d' % n
for n in range(2, 11): PLACES[205 + n] = 'Floor %d' % n
for i, name in PLACES.items():
    col = re.match(r'\{14:[0-9A-F]{2}\}', rows[i]['ja']).group(0)
    T[i] = col + name
T.update({221:' Head', 222:' Body', 223:' Arms', 224:' Right Hand', 225:' Left Hand'})
# job names: the Japanese gives a job 7 cells (menus, status); the English ones longer than 7
# letters are drawn there in condensed letters (insert.py), which hold up to about 13.
# けんし (swordsman) as Knight in たまねぎけんし/まけんし/りゅうきし; まかいげんし (illusionist of
# the demon world, who calls its beings) as Summoner
JOBS = ['Onion Knight','Warrior','Monk','White Wizard','Black Wizard','Red Wizard','Hunter',
 'Knight','Thief','Scholar','Geomancer','Dragon Knight','Viking','Karateka','Magic Knight',
 'Illusionist','Bard','Warlock','Guru','Summoner','Sage','Ninja']
for i, j in enumerate(JOBS): T[226 + i] = j
T.update({248:'Princess Sara', 249:'Old Man Cid', 250:'Desch', 252:'Elia', 253:'Prince Alus',
          254:'Doga', 255:'Unne'})

# name-entry grid (#33): Latin letters in the original 17x10 layout, icons kept
cols = ['01','03','05','07','09','0C','0E','10','12','14']
chars = list('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789') + \
        list(".,'-!?&/:()") + ['[74]', '[75]', '[72]']
chars += [' '] * (170 - len(chars))
T[33] = '\n'.join(''.join('{17:%s}%s' % (c, chars[r*10 + k]) for k, c in enumerate(cols)) for r in range(17))

# item menu (#61): the Japanese two columns of 13 cells (icon, 7 letters, ':', count) as one
# column of 32 full-length names, the count at the right column's place (insert.py: cursor
# step 4); the last line is the bin
T[61] = '\n'.join('{17:01}{1A:%02X}{14:19}{1C:%02X}' % (k, k) for k in range(32)) + '\n{17:05}{0F}'
for i in (32, 37, 47, 48, 50, 51, 52, 57, 59, 60, 72, 73, 74, 109):
    T[i] = codes_only(i)
apply(P, T)
