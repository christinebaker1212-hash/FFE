"""FF3 table B ($8200): system messages, shops, menus, places, jobs, characters."""
import json, re, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from apply import apply

P = 'script/ff3/t8200.json'
rows = json.load(open(P))
def codes_only(i):            # entries with no text: copy layout codes, full-width space -> space
    return rows[i]['ja'].replace('　', ' ')

T = {
 1: ' From inside the treasure\n chest, you got {03} Gil!',
 2: ' Inside the treasure chest\n there was\n {02}!\n Suddenly, monsters\n appeared!!',
 3: ' The door is locked!',
 4: ' Innkeeper: "Welcome!\n To restore your party\'s\n [77][79], it will cost\n {04} Gil.\n Will you stay the night?"',
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
 54: ' {10:02}{15:09}Use{15:0F}Swap{15:16}Item',
 55: ' Status', 56: ' Save',
 58: "{0E}To change to this job, it\nseems you don't have\nenough experience.",
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
 75: '{0E}Please choose the\nfile to save to.',
 76: '{0E}The old data will be\nerased.{15:0E}Yes{15:12}No',
 77: 'Saving is complete.',
 78: '{0E}Hold RESET while you\nturn the power off.',
 79: 'Thank you very much.\nPlease rest well...',
 80: 'Your inventory is full.',
 81: 'Fat Chocobo: "Yooo,\n need somethiiing?"',
 82: '"Whatcha gonna give meee?"',
 83: '"Whaddaya want, ya saaay?"',
 84: '"Time to diiig in.\n Munch munch..."',
 85: '"I can\'t eat no more of\n the same stuff, ya know"',
 86: '"Your stuff\'s full, so I\n can\'t give it back, huh"',
 87: '"I can\'t give it all\n back, so I\'ll hang on\n to the rest"',
 88: '"Hang on a sec, I\'m\n gettin\' it out now..."',
 89: ' Inside the treasure chest\n there was\n {02}!',
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
 113: "{0E}You can't change jobs\nunless you remove all\nyour equipment.",
 114: '     Not enough Capacity!',
 115: 'Who will hold this magic?', 116: "Can't hold any more.",
 117: 'Already holds this magic.',
 118: ' In a place like this,\n {02}!',
 119: " It's too cramped here\n to become big.",
 120: ' Warping impossible', 121: ' Magic cannot be used',
 122: " With the Thief's special\n ability, the lock opened\n just like that!",
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
 186:'Great Ship Invincible', 187:'Labyrinth of the Ancients', 188:'Crystal Tower',
 189:"Xande's Chamber", 190:'World of Darkness', 191:'Basement Floor 1',
 192:'Crystal of Water', 193:'Crystal of Earth', 194:'Dark Crystal of Wind',
 195:'Dark Crystal of Fire', 196:'Dark Crystal of Water', 197:'Dark Crystal of Earth',
 198:'Saronia Underground Maze', 199:'Forbidden Land Eureka',
 216:'Floor 1', 217:'Saronia Library', 218:'Village of Doga', 219:'Forest of Healing',
 220:"King of Sasune's Chamber",
}
for n in range(2, 9): PLACES[198 + n] = 'Basement Floor %d' % n
for n in range(2, 11): PLACES[205 + n] = 'Floor %d' % n
for i, name in PLACES.items():         # centred in the place window (26 cells), as the Japanese
    assert len(name) <= 26, name
    T[i] = '{14:%02X}' % ((26 - len(name)) // 2) + name
T.update({221:' Head', 222:' Body', 223:' Arms', 224:' Right Hand', 225:' Left Hand'})
# job names: the Japanese gives a job 7 cells (menus, status); the English ones longer than 7
# letters are drawn there in condensed letters (insert.py), which hold up to about 13.
# けんし (swordsman) as Knight in たまねぎけんし/まけんし/りゅうきし; まかいげんし (illusionist of
# the demon world, who calls its beings) as Summoner
JOBS = ['Onion Knight','Warrior','Monk','White Wizard','Black Wizard','Red Wizard','Hunter',
 'Knight','Thief','Scholar','Geomancer','Dragon Knight','Viking','Karateka','Magic Knight',
 'Illusionist','Bard','Warlock','Guru','Summoner','Sage','Ninja']
for i, j in enumerate(JOBS): T[226 + i] = j.ljust(7)     # 7 cells, as the Japanese
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
# shops (windows $14-$19, insert.py): the sign as two one-row lines in its 6 cells; the
# shopkeeper's lines one-row, two of 19 cells; Buy/Sell/Exit with the cursor's room (the
# window widened); "How many?" above its choices; the buy list one-row, each price under its
# item's full name
T.update({7: '{0E}Weapon\n Shop', 8: '{0E}Armor\n Shop', 9: '{0E} Item\n Shop', 10: '{0E}Magic\n Shop',
          11: '{15:01}Buy{15:06}Sell{15:0B}Exit',
          38: '{0E}Welcome! What is\nyour business?',
          39: '{0E}What shall it be?',
          40: '{0E}Thank you so much!\nAnything else?',
          41: '{0E}Thank you for your\npatronage.',
          42: '{0E}What will you sell?',
          43: '{0E}That will come to\n{04} Gil.',
          44: "{0E}You're carrying too\nmuch to buy more.",
          45: '{0E}{14:02}How many?\n{15:02}1{15:06}4{15:0A}10',
          46: '{0E}{14:02}How many?\n{15:02}1{15:06}All',
          80: '{0E}Your inventory is\nfull.',
          108: "{0E}You don't have\nenough money.",
          115: '{0E}Who will hold this\nmagic?', 116: "{0E}Can't hold any\nmore.",
          117: '{0E}Already holds this\nmagic.'})
# item and magic prompts (window $15, 19 cells): one-row, two lines
T.update({91: '{0E}Whose [77][79] will you\nrestore?', 92: '{0E}Whose [77][79] will you\nrestore?',
          93: '{0E}Whom will you fully\nrestore?', 94: '{0E}Whom will you bring\nback to life?',
          95: '{0E}Cures the state of\nstone.', 96: '{0E}Restores one who\nbecame a frog.',
          97: '{0E}Cures silence.', 98: '{0E}Makes one small,\nand back again.',
          99: '{0E}Restores eyesight.', 100: '{0E}Whose poison will\nyou cure?',
          101: '{0E}Warps outside.', 102: '{0E}Whose status will\nyou cure?',
          103: '{0E}Go back how many\nfloors?', 104: '{0E}Warps outside.',
          105: '{0E}Turns into a frog\nand back. One/All', 106: '{0E}Makes small and\nback. One/All'})
T[32] = '{0E}' + '\n'.join('{16:01}{19:%02X}\n{14:0C}{21:%02X} Gil' % (k, k) for k in range(8))
# equipment messages (window $1E, widened to 28 cells by insert.py): one row per line (code
# 0E), wrapped in two lines where the English is longer than a line
def msg2(text, width=28):
    lines = ['']
    for w in text.split(' '):
        if lines[-1] and len(lines[-1]) + 1 + len(w) > width: lines.append(w)
        else: lines[-1] = (lines[-1] + ' ' + w) if lines[-1] else w
    assert len(lines) <= 2, text
    return '{0E}' + '\n'.join(lines)
for i in list(range(0x3F, 0x47)) + [0x6B, 0x6E, 0x6F]:
    T[i] = msg2(T[i].strip(' ').replace('Effect..', 'Effect‥'))
T[0x42] = '{0E}Effect‥\nIntelligence rose by 5!'      # (not "... rose by" / "5!")
# equipment window (#62): one row per line (code 0E), each piece on a line of its own in full
# (insert.py: cursor step 4, "Remove Equipment" the sixth entry, the portrait at the right)
T[62] = ('{0E} {10:02}\n'
         ' Attack‥ {10:33}{14:0D}Defense‥ {10:34}\n'
         '{15:01}{10:06}{10:43}\n{15:01}{10:07}{10:44}\n'
         '{15:01}{10:03}\n{15:01}{10:04}\n{15:01}{10:05}\n'
         '{15:01}Remove Equipment')
# equipment candidates (#47, code 20): one column of full names as the item menu (#61)
T[47] = '\n'.join('{17:01}{20:%02X}{14:19}{1C:%02X}' % (k, k) for k in range(32))
# magic screen (#60): one row per line (code 0E), each level's MP on a line of its own above
# its three spells, which have 9 cells each (icon or mark and 8 letters) in place of 7
T[60] = '{0E}' + '\n'.join('%d {10:%02X}/{10:%02X}\n{16:01}{10:%02X}{16:0A}{10:%02X}{16:13}{10:%02X}'
                            % (L + 1, 0x80 + L, 0x88 + L, 8 + 3 * L, 9 + 3 * L, 10 + 3 * L) for L in range(8))
# status screen (#71): one row per line (code 0E, insert.py), the Japanese two columns of
# abilities and combat figures one under the other; copied to RAM whole (16-bit, insert.py)
T[71] = ('{0E}\n{14:0C}{10:02}{14:14}{10:01}\n\n'        # header lines on the Japanese rows
         '{14:0E}Proficiency {10:3D}\n\n'                 #   (the lower of each pair)
         '  [5E][76][5F][76][5E] {10:3E}{14:0E}[76][7A][79] {10:32}\n\n'
         '{14:08}To next level {10:FF}\n\n'
         ' [77][79] {10:30}/{10:31}\n\n'
         ' [78][79] {10:80}/{10:81}/{10:82}/{10:83}/{10:84}/{10:85}/{10:86}/{10:87}\n\n'
         '  Strength{14:14}‥ {10:38}\n'
         '  Agility{14:14}‥ {10:39}\n'
         '  Stamina{14:14}‥ {10:3A}\n'
         '  Intelligence{14:14}‥ {10:3B}\n'
         '  Spirit{14:14}‥ {10:3C}\n\n'
         '  Attack {10:46}x{14:14}‥{10:33}\n'
         '  Hit rate{14:14}‥ {10:42}\n'
         '  Defense {10:47}x{14:14}‥{10:34}\n'
         '  Evasion rate{14:14}‥ {10:41}\n'
         '  Magic defense{14:14}‥{10:36}\n'
         '  Magic evasion rate‥ {10:40}')
for i in (37, 48, 50, 51, 52, 57, 59, 72, 73, 74, 109):
    T[i] = codes_only(i)
apply(P, T)
