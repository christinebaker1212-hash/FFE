"""FF1 native build: the people of the Soul of Chaos floors (docs/ff1-postgame-design.md section 13): the
towns, shops and inns, the puzzle floors and the fights with people, as Dawn of Souls has them, in FF1's
look. A floor's people are map objects with ids PG_NPC0 + n (src/pg.s pg_npc), FF1's own sprites; each
has a small script (the ops below). Their words are the English of Dawn of Souls' Japanese lines (the
message numbers in the user's GBA ROM); FF1's own formations are the people's battles.

Where the people stand: Dawn of Souls' event scripts are not decoded (docs/ff1-postgame-gba.md), so they
are placed on the converted floor at build time (place()): spread over the walkable cells the party can
reach, quest-givers near the start, the hidden and the culprits far away, and a person who stands still
never on a cell the way through needs.

A floor's flags (16, PG_PF in the save page) are cleared when the party arrives; a floor with a gate holds
its stairs (pg.s pg_open) until the gate's flags are all set."""

# ---- script ops (pg.s pg_npc): (name, code, operand bytes); jumps go to an offset in the script
OPS = dict(end=0x00, say=0x01, ifset=0x02, set=0x03, fight=0x04, hide=0x05, ifall=0x06, ifboss=0x07,
           shop=0x08, heal=0x09, mpup=0x0A, drain=0x0B, give=0x0D, goto=0x0F, sfx=0x10)
OPEN = 15                       # the gate flag a person sets (most gates)
PG_NPC0 = 0xD0

# FF1's map sprites (object graphics) used here
G_WOMAN, G_MAN, G_HOOD, G_OLD, G_WITCH, G_HEAD, G_TOWN, G_KID, G_DWIZ, G_GIRL, G_SAGE = 0, 1, 2, 3, 5, 6, 7, 8, 9, 10, 11
G_DWARF, G_MERMAID, G_LUFE, G_KING, G_BAT, G_KNIGHT, G_FAIRY, G_ROBOT, G_DRAGON, G_BAHAMUT = 12, 13, 14, 15, 17, 18, 20, 21, 22, 23
G_BOX, G_TITAN, G_VAMPIRE = 27, 28, 29

# FF1's formations (bank 11's table; $80 + n: its second variant)
F_RED_DRAGON, F_BLUE_DRAGON, F_GREEN_DRAGON = 42, 78, 89
F_ASTOS, F_VAMPIRE, F_KRAKEN = 125, 124, 117
F_DEATH_KNIGHT, F_BLACK_KNIGHTS, F_GUARDIANS = 84, 77, 0x80 | 76
F_HILL_GIGAS, F_SPECTERS, F_ZOMBIES = 31, 44, 4

# ---- Dawn of Souls' lines (message number -> English); 'x...' keys are our own short lines (an item
# received, a part found)
T = {
    660: "...I am one who pursues Omega...",
    661: "Fungaaa!",
    662: "Whaaat? You made it all the way here? I may be a lowly octopus, but I won't lose to the likes of "
         "you! Let's fight!!",
    663: "...You are coming with us...",
    664: "...Giiiiii...",
    665: "There are places a ship can't reach. There's treasure there I just can't get at! They say a canoe "
         "or an airship could do it... I hear an airship appears if you use the Float Stone at the desert "
         "oasis... but I haven't found the Float Stone itself yet.",
    666: "I will give this kingdom to no one! No one shall stand in my way!",
    667: "Wh... what is this... My army... wiped... out...",
    668: "My soul is with the king...",
    669: "My dear... I love you... forever...",
    670: "En... enemy attack!!",
    671: "Whoever invades this kingdom, I will deal with myself!",
    672: "Even with a body like this, I must go on living...",
    673: "...Kill me...",
    674: "Why did it come to this...",
    675: "You did well to come. This is the place where those with courage are tested, to see if they are "
         "fit to go on. If you wish to go on, defeat all of my disciples here: a Red Dragon, a Blue Dragon "
         "and a Green Dragon. If you wish to know how many you have beaten, speak to me.",
    676: "What remains... Defeat them all!",
    677: "You have shown that you are fit to go on. Very well... go on. But do not forget: from here, the "
         "true trial begins.",
    678: "What is it? Have you lost your nerve?",
    679: "Human guests are rare...",
    680: "I am still unworthy... I must be recognized by Lord Dark Bahamut soon...",
    681: "I pray that your future is filled with light...",
    682: "I worry about the family I left behind in the world above.",
    683: "Going back to the world above now and then might not be bad!",
    684: "He... help us... The one deep inside turned us into this... If he is beaten, we should go back "
         "to how we were! You will take up our hopes, won't you!",
    685: "We are counting on you... Be sure to beat him...",
    686: "Wa... wait...",
    687: "He... help... me...",
    688: "It hurts... it hurts... Someone... help...",
    689: "...It's agony...",
    690: "Wh... why... I never did... anything wrong...",
    691: "..............",
    692: "You saved us. This town is really covered in flowers, a truly beautiful town. Please, rest your "
         "heart here for a while.",
    693: "Living on while rotting? No thanks!",
    694: "Phew, thank you so much.",
    695: "Not dying might not be so bad, though!",
    696: "Now I can go to the church. Thank you!",
    699: "Oh, you really saved us!",
    700: "Now peace will return to the town! Thank you so much!",
    701: "Where did that Phantom Train come from?",
    703: "Thank you so very much.",
    704: "At last I can walk normally again.",
    707: "Cough! Cough! I might have eaten something strange!",
    708: "The flowers bloomed beautifully this year...",
    709: "Flowers, flowers, flowers!",
    711: "The sweet smell of flowers drifts by.",
    712: "Ahh, the stiffness in my shoulders is gone!",
    714: "Wow, for a while there I didn't know what would happen!",
    717: "You really saved us! Not that I have a reward for you... Come and visit this town again!",
    721: "May the Phantom Train never appear again!",
    724: "...Friend... won't move... Parts... two... missing... Somewhere... are there any... Please... "
         "look for them...",
    725: "Parts... one more... missing...",
    726: "Friend... fixed... I... happy... Thank you...",
    727: "Friend... moving... Happy...",
    728: ".........",
    729: "Master... where are you going...",
    730: "Gigi... gaga...",
    731: "Gau, gawauu.", 733: "Gawau! Gauwa!", 736: "Gauga, gawau!", 738: "Gagaga... gau!",
    739: "Gaugau? Gagaga!", 741: "Gaugau!! Gau!!",
    747: "My dear giant beavers have run off... Sorry to ask, but would you talk to the beavers and lead "
         "them back home for me? Call on me when you are done.",
    748: "Lead them all home! Are you done already?",
    749: "Let's see...",
    750: "Oh! You did well! This is my thanks!",
    752: "If they run off again, I'm counting on you.",
    753: "I've been seeing a big person a lot lately.",
    754: "I haven't seen the big person lately.",
    756: "Oh, a human? How rare. Hardly anyone but mermaids comes to this village.",
    757: "A dangerous-looking person ran off toward the big room... What was that about?",
    758: "Where did that dangerous-looking person go?",
    762: "Maybe I'll take a walk outside now and then... Staying shut up in my room isn't good for me.",
    766: "I'm going to play by the water now! Come play with me!",
    767: "There was a person with lots of weapons in the room. I got scared and ran away.",
    768: "The person with lots of weapons is gone. ...It's a little lonely.",
    774: "I wonder what it's like up on land... I want to go someday.",
    781: "The big person looks scary, but is really nice!",
    782: "The big person has left the village. I wanted to be friends...",
    785: "My, you're under the water here! I'm surprised you're still alive. Huh, the Oxyale? Hmm, so there "
         "is such a thing.",
    787: "Do you like this village? It's quiet and nice, isn't it?",
    788: "Lately I saw a barrel swimming in the sea. What could that be?",
    789: "My friend in the Sunken Shrine said the Warriors of Light came! Eh? Is that you!?",
    791: "Until lately the power of water was very weak, but it seems to be back to normal. I'm glad...",
    795: "It's very peaceful here. Won't you live here with us?",
    798: "Welcome to the mermaid village! Take your time.",
    799: "For a while now this door won't open. Let me think... since a dangerous person started wandering "
         "around this village.",
    800: "Suddenly the door opens again. What was that about...?",
    801: "This is the village of the fairies... Oh, you are the ones from that time... Thank you for "
         "helping us then.",
    802: "We can't live on the surface anymore.",
    803: "I can't trust people or monsters anymore...",
    804: "Eek! Humans!? This village has become dangerous lately... monsters wander around too... I wonder "
         "if the day will come when we leave the village again...",
    805: "The Oxyale is the water of life. We can't give it away so easily.",
    807: "The children want to go out into the world. Just the other day, one went out and was caught by "
         "a human. They say the Warriors of Light saved her, and she came back safely.",
    809: "Maybe I'll go out into the world too. It may be full of new meetings.",
    812: "This is the village of the fairies! The other children are here too! Some of them will surely "
         "lend you their power! But be careful... some of them love mischief. You'll know which when you "
         "talk to them.",
    813: "Aren't you a little tired?",
    814: "How's that? Refreshed, right!",
    815: "You look down... Let's try harder!",
    816: "Keep trying harder and harder!",
    817: "You should struggle a bit more!",
    818: "Do you understand a little better now?",
    819: "Aren't you having a little too much fun? That's no fun at all!",
    820: "There, now it's more interesting!",
    821: "Hey! Listen! I was playing just now, and I found stairs over there!",
    822: "Aren't I clever? Hee hee!",
    823: "I am studying whether a certain psychologist's theories apply to monsters too. Monsters must "
         "have hearts as well.",
    825: "What in the world is the Kraken? How can it be beaten? I don't know. I don't know!",
    826: "If only I could think of a way to make Adamantite, I'd be rich! Ha, hahaha!",
    831: "The waxing and waning of the moon is a mystery. Even the sea feels it!",
    833: "Each person has their own path, decided by fate. I wonder what your fate is?",
    835: "Surely, surely I'll find out! Eh, find out what? Why the crystals shine, of course!",
    837: "I wonder if Unne is doing well...",
    841: "I'm studying the seers in the elves' town. Their prophecies come true remarkably well.",
    843: "The greatest mystery to us is love. What is that feeling?",
    845: "Have you ever had a ghostly experience? Why they appear is wrapped in mystery.",
    851: "Strange powers seem to be gathering. I feel something bad will happen unless I analyse this "
         "power quickly.",
    854: "A hundred years now I have studied how to use white and black magic together. The results still "
         "haven't come. Will my childhood dream never come true?",
    864: "No, no! You can't pass!",
    871: "Blocked! Blocked!",
    876: "Red light, green light... You moved just now! No moving.",
    887: "This is Ballerina, the city of dance. Come, let's all dance!",
    888: "One-two, now together, one-two, one-two.",
    889: "Won't you dance? The sweat feels great!",
    891: "Say, do you want to see me dance? Hee hee, no. Come and see the stage.",
    892: "I got into the Crystal troupe! I'll do my best to become the star!",
    894: "Tantalus Theater! To pass the audition I have to practise more and more!",
    896: "An intense dance! Intense! It feels like dancing, doesn't it!",
    897: "Dancing calms the heart.",
    901: "I'm practising the waltz.",
    902: "I can't dance the tango well...",
    905: "Do you know the samba?",
    907: "Flamenco is passionate, isn't it!",
    915: "Rearrange the letters of LIMBO and you get... no, never mind.",
    919: "Using both white and black magic is the Red Mage's privilege! However... it takes the proper "
         "effort.",
    920: "Curses! Can't I use strong white magic?",
    921: "Curses! Can't I use strong black magic?",
    922: "I want to use white and black magic at the same time...",
    923: "I am studying a way to shorten casting time.",
    924: "I never miss my sword practice.",
    925: "We are sometimes mistaken for warriors, but we are mages.",
    926: "They say there is also such a thing as blue magic...",
    927: "I take pride in being better suited to battle than a Black Mage.",
    928: "Red magic does not exist.",
    929: "Good at fighting, good at support, good at defence. That is my motto.",
    930: "There seem to be such things as magic levels. But I don't know how to raise them faster.",
    931: "We're playing hide-and-seek, but there's one we just can't find... Help us look! If you find "
         "them, I'll tell you something good!",
    935: "Th... there!? Thank you!",
    936: "Oh... there are stairs over there, so go ahead and use them!",
    937: "What! You're it!? Aww... you found me...",
    938: "Aww... found me...",
    939: "Hooray for the town of toys!",
    940: "Papa! Mama! Where are you?",
    941: "Mecha Bahamut is sooo cool!",
    942: "I bought a 1/144 scale airship! When I grow up I'll buy a real one!",
    944: "My papa is rich! Shall I buy this whole town?",
    946: "There are no swings! Boring!",
    947: "I'm getting bored, so I want to go to a more fun town, but I can't find the way out...",
    950: "Sniff, sniff. My... my toy has gone somewhere...",
    954: "Before I knew it, I was in this town. I have to get home soon or I'll be late for cram school.",
    958: "What time is it? I feel like I've played a lot, but it isn't getting dark.",
    964: "Go into that house and you end up in that house, go into that house and you end up in this "
         "one... This town is fun!",
    974: "Mmm, delicious. Hm!? What, you want this candy that badly? Here, have it.",
    975: "Well, it was tasty, wasn't it?",
    976: "Ahh, I'm hungry. If only I had some candy at a time like this...",
    977: "Ohh! That's candy! I can't resist it! You'll give it to me, won't you? Won't you?",
    978: "Thanks. As thanks, I'll give you this ocarina I made long ago.",
    980: "That candy was really delicious.",
    981: "Lately I've been crazy about instruments. If you have a rare instrument, would you give it to me?",
    982: "Ohh! That's a rare instrument. Please, would you give it to me?",
    983: "I'll add it to my instrument collection. Let me see... as thanks, I'll give you something I "
         "collected long ago.",
    985: "That ocarina you gave me is the finest thing in my collection.",
    986: "I want to rebuild the flying ship a Lufenian named Cid built long ago... but I'm short of parts. "
         "Would you look for them, if you can?",
    987: "Ohh, that's the Time Gear! Please, would you give it to me?",
    988: "Thank you, I'm in your debt! This brings my dream of rebuilding the airship one step closer! This "
         "is what I used to gather ore for the airship's parts, but take it as my thanks.",
    990: "Thanks to you, I'll rebuild the airship soon.",
    991: "They say Nerrick, whom I admire, dug a canal. I want to dig a canal like him! But I have no "
         "tools to dig with... Isn't there one somewhere...",
    992: "That's a pickaxe! Will you trade it for my treasure, Nerrick's autograph?",
    993: "Now I can go out and dig a canal.",
    996: "The other day Nerrick, who opened the canal, came here, they say. And I didn't get his "
         "autograph. What a shame.",
    997: "That's Nerrick's autograph! Will you give it to me?",
    998: "Thank you! As thanks, I'll give you this medicine I got long ago from a witch called Matoya.",
    1000: "What? You know Nerrick? I'm so jealous.",
    1001: "My... my stomach... it hurts...",
    1002: "P... please. Give me... that medicine...",
    1003: "Gulp, gulp... Ohh, my stomachache is gone! As thanks, take this tool!",
    1005: "I guess I really shouldn't have eaten something I picked up.",
    1006: "Dwarves are good with their hands. We can make anything. But my tools broke, so I can't make a "
          "thing.",
    1007: "You brought it for me, didn't you?",
    1008: "It's an old-looking tool, but I'll make do. Here, take this; I picked it up a while ago.",
    1010: "I tried this tool and was amazed. It's easier to use than my old one.",
    1011: "What a mess. I dropped my house key and can't get in. Where did I drop it...",
    1012: "Why, that's my house key. You picked it up to bring it to me?",
    1013: "At last I can get into my house. Thank you. As thanks, I'll give you the proof of our fellowship.",
    1015: "Come to think of it, there was a silent man... He won't even talk unless you have the proof of "
          "fellowship.",
    1016: "..........",
    1017: "! That is the proof of fellowship! Then I will trade you this ruby for that proof.",
    1018: "Take that Star Ruby and speak to the giant.",
    'part': "Found a robot part!",
    'giant': "The giant took the Star Ruby, and gave you something in return. Received a Megalixir!",
    'beaver_r': "Received an Elixir!",
    'held_town': "Someone on this floor still needs your help.",
}


def P(gfx, ops, at=None, stand=False):
    """a person: FF1 sprite, script ops, where (None spread, 'near' the start, 'far' from it), still"""
    return dict(gfx=gfx, ops=ops, at=at, stand=stand)


def say(t): return [('say', t)]
def talk(*ts):                                       # (a plain person: one line)
    return [P(g, say(t)) for g, t in ts]


def before_after(cond, before, after):
    """a line until cond (('flag', f) / ('boss', shrine, bit) / ('all', mask)), another after"""
    return [('if',) + cond + ('a',), ('say', before), ('label', 'a'), ('say', after)]


def trade(k, want, give_text, after):
    """a trade in a chain: flag k done (after), flag k - 1 held (the trade: give_text), else want"""
    ops = [('ifset', k, 'done')]
    if k: ops += [('ifset', k - 1, 'do'), ('say', want), ('label', 'do')]
    ops += [('set', k), ('sfx',), ('say', give_text), ('label', 'done'), ('say', after)]
    return ops


# ---- the floors (Dawn of Souls map record -> people, gate (flags that open the stairs), held text)
def floors(shops):
    S = shops
    F = {}
    # Earthgift: the forest's strangers (fights)
    F[138] = dict(people=[P(G_DWIZ, [('fight', F_HILL_GIGAS), ('hide',), ('say', 661)], 'far', True),
                          P(G_DWIZ, [('fight', F_SPECTERS), ('hide',), ('say', 663)], None, True)])
    # Hellfire: Thule on the overworld floors; the waterfall's robots; the fire shrine's bats
    for r in (149, 210, 211):
        F[r] = dict(people=[P(G_MAN, say(665), 'near')])
    F[142] = dict(gate=1 << OPEN, held='held_town', people=[
        P(G_ROBOT, [('ifset', OPEN, 'ok'), ('ifall', 3, 'fix'), ('ifset', 0, 'one'), ('ifset', 1, 'one'),
                    ('say', 724), ('label', 'one'), ('say', 725), ('label', 'fix'), ('set', OPEN),
                    ('say', 726), ('label', 'ok'), ('say', 727)], 'near', True),
        P(G_ROBOT, before_after(('ifset', OPEN), 728, 729), 'near', True),
        P(G_BOX, [('set', 0), ('hide',), ('sfx',), ('say', 'part')], 'far', True),
        P(G_BOX, [('set', 1), ('hide',), ('sfx',), ('say', 'part')], None, True)])
    F[143] = dict(people=talk((G_ROBOT, 729), (G_ROBOT, 730)))
    F[144] = dict(people=talk((G_BAT, 664), (G_BAT, 664), (G_BAT, 664)))
    # Lifespring: Seahold (the mermaid village), the octopus, the dragons' trial, the beavers, the library,
    # the dancers' city, Omega's pursuer
    LS, WW = 2, 3
    F[161] = dict(people=[P(G_MERMAID, say(798), 'near')] +
                  [P(G_MERMAID, before_after(('ifboss', LS, 0), b, a)) for b, a in
                   ((753, 754), (757, 758), (767, 768), (781, 782), (799, 800))] +
                  talk(*[(G_MERMAID, t) for t in (756, 762, 766, 774, 785, 787, 788)]) +
                  [P(G_MERMAID, [('shop', S['seahold_items'])], None, True),
                   P(G_MERMAID, [('shop', S['seahold_inn'])], None, True)])
    F[150] = dict(people=[P(G_DWIZ, [('fight', F_KRAKEN), ('hide',), ('say', 662)], 'far', True)])
    F[160] = dict(people=[P(G_KNIGHT, say(660), 'far', True)])
    dragon = lambda f, k, t: P(G_DRAGON, [('fight', f), ('set', k), ('hide',), ('say', t)], 'far', True)
    F[164] = dict(gate=1 << OPEN, held=678, people=[
        P(G_BAHAMUT, [('ifset', OPEN, 'ok'), ('ifall', 7, 'won'), ('ifset', 14, 'again'), ('set', 14),
                      ('say', 675), ('label', 'again'), ('say', 678), ('label', 'won'), ('set', OPEN),
                      ('label', 'ok'), ('say', 677)], 'near', True),
        dragon(F_RED_DRAGON, 0, 679), dragon(F_BLUE_DRAGON, 1, 680), dragon(F_GREEN_DRAGON, 2, 683),
        P(G_DRAGON, say(681)), P(G_DRAGON, say(682))])
    beaver = lambda k, t: P(G_DWARF, [('set', k), ('hide',), ('say', t)], None, True)
    F[162] = dict(gate=1 << OPEN, held=748, people=[
        P(G_OLD, [('ifset', OPEN, 'ok'), ('ifall', 63, 'won'), ('ifset', 14, 'again'), ('set', 14),
                  ('say', 747), ('label', 'again'), ('say', 748), ('label', 'won'), ('set', OPEN),
                  ('give', 1, 5), ('sfx',), ('say', [749, 750, 'beaver_r']), ('label', 'ok'), ('say', 752)],
                  'near', True)] +
        [beaver(k, t) for k, t in enumerate((731, 733, 736, 738, 739, 741))])
    F[157] = dict(people=talk(*[(g, t) for g, t in zip(
        [G_SAGE, G_OLD, G_DWIZ] * 4, (823, 825, 826, 831, 833, 835, 837, 841, 843, 845, 851, 854))]) +
        [P(G_KID, say(t), None, True) for t in (864, 871, 876)])
    F[153] = dict(people=[P(G_GIRL, say(887), 'near')] +
                  talk(*[(G_GIRL if i % 2 else G_WOMAN, t) for i, t in
                         enumerate((888, 889, 891, 892, 894, 896, 897, 901, 902, 905, 907))]) +
                  [P(G_WOMAN, [('shop', S['dance_items'])], None, True),
                   P(G_MAN, [('shop', S['dance_inn'])], None, True)])
    # Whisperwind: the Western Keep, the swamp, Feyhome, the mages' village, the cursed town, the desert
    # town's trades, the town of toys
    F[174] = dict(gate=7, held='held_town', people=[
        P(G_KING, [('fight', F_DEATH_KNIGHT), ('set', 2), ('hide',), ('say', 666)], 'far', True),
        P(G_WOMAN, before_after(('ifset', 2), 668, 669), 'far', True),
        P(G_KNIGHT, [('fight', F_BLACK_KNIGHTS), ('set', 0), ('hide',), ('say', 670)], None, True),
        P(G_KNIGHT, [('fight', F_GUARDIANS), ('set', 1), ('hide',), ('say', 671)], None, True)] +
        talk((G_KNIGHT, 672), (G_KNIGHT, 673), (G_KNIGHT, 674)))
    F[176] = dict(gate=3, held=685, people=[
        P(G_HOOD, [('ifall', 3, 'won'), ('ifset', 14, 'again'), ('set', 14), ('say', 684), ('label', 'again'),
                   ('say', 685), ('label', 'won'), ('say', 691)], 'near'),
        P(G_KING, [('fight', F_ASTOS), ('set', 0), ('hide',), ('say', 663)], 'far', True),
        P(G_VAMPIRE, [('fight', F_VAMPIRE), ('set', 1), ('hide',), ('say', 664)], 'far', True)] +
        talk(*[(G_HOOD, t) for t in (686, 687, 688, 689, 690)]))
    fairy = lambda eff, t0, t1, k: P(G_FAIRY, [('ifset', k, 'done'), ('set', k), (eff,), ('say', t0),
                                                ('label', 'done'), ('say', t1)], None, True)
    F[188] = dict(people=[P(G_FAIRY, say(812), 'near')] +
                  talk(*[(G_FAIRY, t) for t in (801, 802, 803, 804, 805, 807, 809)]) +
                  [fairy('heal', 813, 814, 0), fairy('mpup', 815, 816, 1), fairy('drain', 817, 818, 2),
                   fairy('drain', 819, 820, 3), P(G_FAIRY, say([821, 822]))])
    F[182] = dict(people=talk(*[(G_SAGE if i % 2 else G_DWIZ, t) for i, t in
                                enumerate((919, 920, 921, 922, 923, 924, 925, 926, 927, 928, 929, 930))]) +
                  [P(G_SAGE, [('shop', S['mage_white'])], None, True),
                   P(G_DWIZ, [('shop', S['mage_black'])], None, True)])
    town = (692, 693, 694, 695, 696, 699, 700, 701, 703, 707, 709, 714, 717)
    F[175] = dict(people=[P((G_WOMAN, G_MAN, G_OLD, G_KID, G_GIRL)[i % 5],
                            before_after(('ifboss', WW, 2), 691, t), 'near' if i == 0 else None)
                          for i, t in enumerate(town)] +
                  [P(G_MAN, [('shop', S['cursed_items'])], None, True),
                   P(G_WOMAN, [('shop', S['cursed_inn'])], None, True)])
    F[193] = dict(people=[
        P(G_MAN, [('ifset', 0, 'done'), ('set', 0), ('sfx',), ('say', 974), ('label', 'done'), ('say', 975)], 'near', True),
        P(G_TOWN, trade(1, 976, [977, 978], 980), None, True), P(G_OLD, trade(2, 981, [982, 983], 985), None, True),
        P(G_DWARF, trade(3, 986, [987, 988], 990), None, True), P(G_DWARF, trade(4, 991, [992, 993], 993), None, True),
        P(G_MAN, trade(5, 996, [997, 998], 1000), None, True), P(G_TOWN, trade(6, 1001, [1002, 1003], 1005), None, True),
        P(G_DWARF, trade(7, 1006, [1007, 1008], 1010), None, True), P(G_MAN, trade(8, 1011, [1012, 1013], 1011 + 2), None, True),
        P(G_OLD, trade(9, 1016, [1017, 1018], 1018), None, True),
        P(G_TITAN, [('ifset', 10, 'done'), ('ifset', 9, 'do'), ('say', 691), ('label', 'do'), ('set', 10),
                    ('give', 1, 6), ('sfx',), ('say', 'giant'), ('label', 'done'), ('say', 691)], 'far', True),
        P(G_MAN, say(1015)),
        P(G_DWARF, [('shop', S['desert_items'])], None, True),
        P(G_MAN, [('shop', S['desert_inn'])], None, True)])
    F[131] = dict(gate=1 << OPEN, held='held_town', people=[
        P(G_KID, [('ifset', OPEN, 'ok'), ('ifset', 0, 'found'), ('say', 931), ('label', 'found'),
                  ('set', OPEN), ('say', [935, 936]), ('label', 'ok'), ('say', 936)], 'near', True),
        P(G_KID, [('ifset', 0, 'done'), ('set', 0), ('say', 937), ('label', 'done'), ('say', 938)], 'far', True)] +
        talk(*[(G_KID if i % 2 else G_GIRL, t) for i, t in
               enumerate((939, 940, 941, 942, 944, 946, 947, 950, 954, 958, 964))]))
    return F


# ---- the shops (new shop ids from FF1's 71 on: names bank N_STYPE / N_SITEMS; prices of the new
# consumables at N_CPRICE)
FF1_SHOPS = 71
SHOP_DEFS = [('seahold_items', 6, ['Hi-Potion', 'Ether', 'Phoenix Down', 'Remedy', 'Echo Grass']),
             ('seahold_inn', 5, 300),
             ('dance_items', 6, ['Hi-Potion', 'X-Potion', 'Ether', 'Phoenix Down', 'Eye Drops']),
             ('dance_inn', 5, 400),
             ('cursed_items', 6, ['X-Potion', 'Turbo Ether', 'Phoenix Down', 'Remedy', 'Emergency Exit']),
             ('cursed_inn', 5, 600),
             ('desert_items', 6, ['Hi-Potion', 'X-Potion', 'Ether', 'Turbo Ether', 'Phoenix Down']),
             ('desert_inn', 5, 500)]


def shop_ids(rom):
    """{name: shop id}: ours from FF1_SHOPS on, and the mages' village's magic shops (FF1's two with the
    highest-level spells: white, black)"""
    import names
    types, items, _ = names.shop_tables(rom)
    ids = {n: FF1_SHOPS + i for i, (n, _, _) in enumerate(SHOP_DEFS)}
    best = {}
    for k in range(71):
        if types[k] in (2, 3):
            lv = max(items[5 * k:5 * k + 5])
            if types[k] not in best or lv > best[types[k]][0]: best[types[k]] = (lv, k)
    ids['mage_white'], ids['mage_black'] = best[2][1], best[3][1]
    return ids


def shop_data():
    """(types, 5-byte item lists) of our shops; item codes: FF1's, or a new consumable's $C0 + k"""
    import postgame
    cons = [c[0] for c in postgame.NEW_CONS]
    types, items = bytearray(), bytearray()
    for n, ty, it in SHOP_DEFS:
        types.append(ty)
        if ty == 5: items += it.to_bytes(2, 'little') + bytes(3)
        else: items += bytes(postgame.C_CONS + cons.index(x) for x in it).ljust(5, b'\0')
    return bytes(types), bytes(items)


def cons_prices():
    """the new consumables' prices (2 bytes each, by k) for N_CPRICE"""
    import postgame
    out = bytearray()
    for c in postgame.NEW_CONS:
        out += postgame.NEW_PRICE.get(c[0], 0).to_bytes(2, 'little')
    return bytes(out)


# ---- placing the people
def place(rec, f, people, walk, reach, prop=None):
    """(x, y, flags) for each person on floor f (map coordinates): walk = the floor's walkable cells, reach
    = {cell: steps from the start}; prop = the floor tileset's property bytes (the way through is checked by
    them: what the party can really walk)"""
    import random
    from collections import deque
    rnd = random.Random(rec)
    start = tuple(f['start'])
    if prop is not None:                             # (passable by the tiles' properties; stairs as goals)
        def pas(c):
            p = prop[2 * f['map'][64 * c[1] + c[0]]]
            if p & 0x1E in (2, 4, 6): return True
            return not (p & 1) and (p & 0x1E) != 8 and not (p & 0xC0)
        seen = {start: 0}; dq = deque([start])
        while dq:
            c = dq.popleft()
            for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = ((c[0] + a) % 64, (c[1] + b) % 64)
                if n not in seen and pas(n): seen[n] = seen[c] + 1; dq.append(n)
        reach = seen
        rooms = set(f.get('rooms', ()))
        walk = set(walk) | {c for c in rooms if c in reach and (prop[2 * f['map'][64 * c[1] + c[0]]] & 0x1E) != 8}
    else: rooms = set()
    keep = {start} | set(map(tuple, f['stairs'])) | {(c[0], c[1]) for c in f['chests']}
    near = lambda p: [((p[0] + a) % 64, (p[1] + b) % 64) for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))]
    bad = set(keep)
    for p in keep: bad |= set(near(p))
    cand = [p for p in reach if p in walk and p not in bad and reach[p] > 2]
    taken, out = set(), []
    need = [q for p in keep for q in near(p) if q in reach] + [start]

    def ok_still(p):                                 # (the way through kept: every needed cell still reached)
        blocked = taken | {p}
        seen = {start}; dq = deque([start])
        while dq:
            c = dq.popleft()
            for n in near(c):
                if n in reach and n not in blocked and n not in seen:
                    seen.add(n); dq.append(n)
        return all(q in seen for q in need) and \
            all(any(n in seen for n in near(t)) for t in blocked)
    far_max = max(reach[p] for p in cand) if cand else 1
    for pe in people:
        def score(p):
            dmin = min([abs(p[0] - q[0]) + abs(p[1] - q[1]) for q in taken] + [99])
            if pe['at'] == 'near': return -reach[p] * 4 + min(dmin, 4) + rnd.random()
            if pe['at'] == 'far': return reach[p] * 2 + min(dmin, 6) + rnd.random()
            return min(dmin, 12) * 3 + reach[p] / far_max + rnd.random()
        loose = [p for p in reach if p in walk and p not in keep and p not in taken]   # (a small floor)
        for p in sorted((c for c in cand if c not in taken and not set(near(c)) & taken), key=score, reverse=True) + \
                sorted(loose, key=score, reverse=True):
            if ok_still(p):
                taken.add(p); out.append((p[0], p[1], (0x40 if pe['stand'] else 0) | (0x80 if p in rooms else 0))); break
        else:
            out.append(None)                         # (no room: this person is left out)
    return out


# ---- the code bank's tables (pg.s): per map its record (gate, held text, the people's scripts)
def resolve(ops):
    """ops -> bytes with text references [(offset, text key)] (a say's two bytes filled by the assembler)"""
    labels, size = {}, 0
    L = dict(end=1, say=3, ifset=3, set=2, fight=2, hide=1, ifall=4, ifboss=4, shop=2, heal=1, mpup=1, drain=1,
             give=3, goto=2, sfx=1)
    for o in ops:
        if o[0] == 'label': labels[o[1]] = size
        else: size += L[o[0]]
    if ops[-1][0] not in ('say', 'shop', 'end', 'goto'): size += 1
    out, refs = [], []
    for o in ops:
        n = o[0]
        if n == 'label': continue
        if n == 'say':
            refs.append(o[1]); out.append(('say', o[1]))
        elif n == 'ifset': out.append(bytes([OPS[n], o[1], labels[o[2]]]))
        elif n == 'ifall': out.append(bytes([OPS[n], o[1] & 0xFF, o[1] >> 8, labels[o[2]]]))
        elif n == 'ifboss': out.append(bytes([OPS[n], o[1], o[2], labels[o[3]]]))
        elif n == 'goto': out.append(bytes([OPS[n], labels[o[1]]]))
        elif n in ('set', 'fight', 'shop'): out.append(bytes([OPS[n], o[1]]))
        elif n == 'give': out.append(bytes([OPS[n], o[1], o[2]]))
        else: out.append(bytes([OPS[n]]))
    if ops[-1][0] not in ('say', 'shop', 'end', 'goto'): out.append(bytes([0]))
    return out


def _norm(ops):
    """before_after's ('if', kind, ..., label) -> the op it names"""
    out = []
    for o in ops:
        if o[0] == 'if':
            kind = o[1]
            out.append((kind,) + tuple(o[2:]))
        else: out.append(o)
    return out


def tkey(t):
    return '_'.join(str(x) for x in t) if isinstance(t, list) else str(t)


def text_of(t):
    return ' '.join(T[x] for x in t) if isinstance(t, list) else T[t]


def source(rom, fl, PGT_BANK):
    """the asm: bank 116's per-map table (pg_evt) and scripts, bank PGT_BANK's texts"""
    import text
    def db(b): return ''.join('            db ' + ', '.join('$%02X' % x for x in b[i:i + 16]) + '\n'
                              for i in range(0, len(b), 16))
    F = FLOORS_BUILT
    code = 'section bank 116, $7330\npg_evt:\n'
    for e in fl:
        code += '            dw %s\n' % ('pge_m%d' % e['map'] if e['rec'] in F and e['role'] != 'boss' else '0')
    texts = {}
    for e in fl:
        if e['rec'] not in F or e['role'] == 'boss': continue
        d = F[e['rec']]
        held = d.get('held')
        if held is not None: texts[tkey(held)] = held
        code += 'pge_m%d:\n            dw $%04X\n            dw %s\n            db %d\n' % (
            e['map'], d.get('gate', 0), 'pge_t' + tkey(held) if held is not None else '0', len(d['people']))
        code += ''.join('            dw pge_m%d_%d\n' % (e['map'], i) for i in range(len(d['people'])))
        for i, pe in enumerate(d['people']):
            code += 'pge_m%d_%d:\n' % (e['map'], i)
            for part in resolve(_norm(pe['ops'])):
                if isinstance(part, tuple):
                    code += '            db $01\n            dw pge_t%s\n' % tkey(part[1])
                    texts[tkey(part[1])] = part[1]
                else: code += db(part)
    tx = 'section bank %d, $4800\n' % PGT_BANK
    for k, t in texts.items():
        tx += 'pge_t%s:\n' % k + db(text.encode_dialogue(text_of(t)))
    return code + tx


FLOORS_BUILT = {}


def build(rom):
    """the floors' people (by Dawn of Souls map record), with the shop ids filled in"""
    if not FLOORS_BUILT:
        FLOORS_BUILT.update(floors(shop_ids(rom)))
    return FLOORS_BUILT
