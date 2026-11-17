import sys, os, json
sys.path.insert(0, os.path.dirname(__file__))
from apply import apply
S = {
0:' There is nothing in that direction.',
1:' From inside the treasure chest\n {02} was obtained.',
2:' From inside the treasure chest\n {03} Gil was obtained.',
3:' Your belongings are full.\n You cannot take any more!',
4:' The lock is already open.',
5:' Welcome.\n How may I help you?',
6:' What may I\n get for you?',
7:" You don't seem to have enough money.\n Anything else?",
8:" You seem to be carrying too much\n to hold any more.\n If there's something you'd like to sell,\n I'll take it off your hands.",
9:' Thank you very much.\n Anything else?',
10:' What will you sell me?',
11:" I can't take that.\n Anything else?",
12:"I'll buy it for {04} Gil.\n Is that all right?\n{16:08}Yes{16:16}No",
13:' Welcome, you must be weary.\n To restore your HP/MP\n it will cost {04} Gil.\n Will you stay the night?',
14:" You don't seem to have enough money.\n I'm sorry, but I can't let you stay...",
15:' Good night, sweet dreams...',
16:' Please come again!',
17:" Hey, you lot, want to ride a ship?\n I'll take you to Poft\n for 32 Gil!",
18:" Hey, you lot, want to ride a ship?\n I'll take you to Palm\n for 32 Gil!",
19:" All right then, the ship's waiting\n out front of town, so climb aboard.",
20:"Cid's Henchman: \"So you want to ride Big Bro Cid's airship,\nthe only one in the whole world?\nI'll take you anywhere, however far, in no time flat!\nThat is, provided you've got the money...\"",
21:' Where are{16:0D}Bafsk        100\n you headed?{16:0D}Salamand     200\n{16:0D}Semite Falls 300\n{16:0D}Kashuon      400',
22:"Heh heh, thank ya kindly!\nThe airship's all ready on the airfield\noutside, so climb aboard.",
23:'{15:01}Buy\n{15:01}Sell\n{15:01}Pass',
24:'{15:01}Yes\n{15:01}No',
25:" Whoa, looks like you're short on money.\n Sorry, but I can't take you like that.\n Come back another time.",
26:'{15:01}Ask\n{15:01}Learn\n{15:01}Items',
27:'{15:02}Items{15:0A}Magic{15:12}Equip\n{15:02}Status{15:0A}Save',
28:'{05} Gil',
31:' Items',
32:' Magic\n  {10:02}',
33:' HP {10:20}/{10:21}\n MP  {10:22}/ {10:23}',
34:' Equip\n  {10:02}',
35:' Attack .. {10:24}\n Defense .. {10:25}',
36:' Right Hand{14:0A}Head{14:13}Arms\n{16:02}{10:06}{16:0B}{10:03}{16:14}{10:05}\n Left Hand{14:0A}Body{14:13}Item\n{16:02}{10:07}{16:0B}{10:04}{16:14}{10:08}\n{16:14}{10:09}',
39:'{14:05}{10:02}{14:0E}HP {10:20}/{10:21}\n{14:0E}MP  {10:22}/ {10:23}\n Strength     .. {10:26}  {10:00}\n Agility      .. {10:27}  Attack        .. {10:24}\n Stamina      .. {10:28}  Hit Rate      .. {10:2D}%\n Intelligence .. {10:29}  Defense       .. {10:25}\n Spirit       .. {10:2A}  Evasion       .. {10:2E}%\n Magic Power  .. {10:2B}  Magic Defense .. {10:2F}%\n......................................................\n Skill Level   [70] {10:32}  [73] {10:35}\n [6E] {10:30}  [71] {10:33}  [74] {10:36}\n [6F] {10:31}  [72] {10:34}  [75] {10:37}',
40:' Data will be written to this file\n The previous data will be lost\n Is that all right?{16:09}Yes{16:0D}No',
41:' Save to which number?\n{16:03}1{16:06}2{16:09}3{16:0C}4',
42:' Save complete! When you stop playing,\n be sure to hold down the RESET button\n while you turn the power off!!',
43:' Medicine that restores HP.\n On whom will you use it?',
44:' An antidote that neutralizes poison in the body.\n On whom will you use it?',
45:' Cures the state of stone.\n On whom will you use it?',
46:' A holy cross that lifts curses.\n On whom will you use it?',
47:' Cures someone who has been turned into a frog.\n On whom will you use it?',
48:" When someone has forgotten their magic, give their\n head a jolt with this mallet and it\n comes back. On whom will you use it?",
49:' Eye drops that restore eyesight.\n On whom will you use it?',
50:' The tail of the immortal bird Phoenix,\n which brings the dead back to life.\n Whom will you revive?',
51:' Fully restores HP/MP.\n On whom will you use it?',
52:" Whose MP will you restore?",
53:' Greatly restores HP.\n On whom will you use it?',
54:" With this portable cottage, by the next morning\n everyone's HP/MP will be fully restored.",
55:' Goes back along the way you just came,\n as many steps as the magic level.',
56:' Restores HP.\n On whom will you cast it?',
57:' Brings the dead back to life.\n Whom will you revive?',
58:' Magic that cures\n various ailments.\n On whom will you cast it?',
59:" Magic that warps you straight to the surface.\n Until you're used to it, it consumes\n a great deal of HP.",
}
rows = {e['id']: e for e in json.load(open('script/ff2/system.json'))}
for k in (29, 30, 37, 38):          # pure layouts: keep codes, ASCII spaces
    S[k] = rows[k]['ja'].replace('　', ' ')
apply('script/ff2/system.json', S)

# --- part 2 ---
S2 = {
60:' Who will learn the spell?',
61:' You already know this spell.',
62:" You have too many spells to learn\n any more right now.\n First discard a magic you don't need.",
63:'\n You have no words you can learn.',
64:" You can't save here!\n Please save on\n the world map.",
68:' Nothing happened.',
71:' There is an invisible\n energy field here, and you\n cannot warp!',
72:' When you offer a prayer,\n a warm light suddenly envelops everything around,\n and from nowhere a voice brimming\n with kindness rings out...\n "O lost soul of the dead...\n from the distant land ruled by sorrow and darkness,\n now return to life!!"\n',
73:"In a world far, far away...\nthe peace that had long endured has now come to an end.\nThe Emperor of Palamecia summoned monsters from\nthe Demon World and set out to conquer the world.\n\nAgainst this, the rebel army rose up in the Kingdom of Finn\nbut, met with the Empire's all-out attack,\nit lost its castle and was forced to retreat\nto the remote town of Altea.\n\nFour young people living here in the Kingdom of Finn\nalso lost their parents to the enemy's attack\nand kept fleeing from their relentless pursuers...",
74:'  {10:02}{14:09}HP {10:20}/{10:21}\n Speed {06}  MP  {10:22}/ {10:23}',
75:' New Game  Speed {06}',
76:' From inside the treasure chest\n {02} was obtained.\n Suddenly, monsters appeared!',
77:' In your current condition\n you cannot learn magic.',
240:'Poison', 241:'Sleep', 242:'Silence', 243:'Tiny', 244:'Paralysis', 245:'Confusion', 247:'Blindness',
248:'Deadly Poison', 249:'Curse', 250:'Forgetful', 251:'Frog', 252:'Stone', 253:'Dead',
254:'Right-handed', 255:'Left-handed',
}
for k in (65, 66, 67, 69):
    S2[k] = rows[k]['ja'].replace('　', ' ')
# name entry grid (the Japanese 16 rows x 10 cells, same column codes): Latin letters,
# digits and punctuation in 8 rows; the last cells are spaces
cells = list('ABCDEFGHIJKLMNOPQRSTUVWXYZ' "abcdefghijklmnopqrstuvwxyz" '0123456789' ".,'-!?&/:()" '";+%') + [' '] * 3
cols = [0x01,0x03,0x05,0x07,0x09,0x0C,0x0E,0x10,0x12,0x14]
S2[70] = '\n'.join(''.join('{17:%02X}%s' % (c, cells[r*10+i]) for i, c in enumerate(cols)) for r in range(8))
apply('script/ff2/system.json', S2)
