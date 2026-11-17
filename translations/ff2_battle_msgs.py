import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from apply import apply
B = ['Fight','Run','Magic','Gear','Right Hand','Left Hand','Items','MP Cost',"Magic can't be used",
 'A chance to strike first!!','The monsters strike first!',' hits',' damage','Critical hit!!','Miss',
 'Ran away',"Can't escape!",'Is asleep','Is paralyzed','Did nothing','Had no effect',
 ' was defeated!',' was slain!',"'s party was wiped out",'Won the battle!!','Life was taken   ',
 'Turned to stone','Turned into a frog?!','Forgot magic??','Was cursed','Struck by deadly poison',
 'Can no longer see','Became confused??','Was paralyzed','Became small?!','Was silenced','Fell asleep',
 'Was poisoned','Came back to life','Returned to a body of flesh','Returned to human form',
 'Regained memory','The curse was lifted','The deadly poison vanished','Can see again','Calmed down',
 'The paralysis wore off','Returned to original size','The silence was broken','Woke up',
 'The poison wore off','Scared them stiff','Became better at dodging attacks','Became resistant to magic',
 ' went down','Swapped HP and MP','Built a wall against black magic','The wall was broken',
 'Blocked the magic','Split apart',' level went up','Number of attacks',' went down!!',' went up!!',
 'Cold attack','Nerve attack','Poison attack','Death','Lightning attack','Spirit attack','Fire attack',
 'Transformation attack',' is blocked!!','White','Yellow','Green','Black','Blue','Orange','Red','Purple',
 ' aura envelops them!','Cold','Nerve','Poison','Death blocked','Lightning','Spirit','Fire','Transformation',
 'The barrier vanished!!','Attack Power','Defense Power','HP','MP','Strength','Intelligence','Spirit',
 'Agility','Stamina','Magic Power',' rose!!',' went up!!',' went down',' was drained',' drained!!',
 ' recovered!!',' Gil obtained',
 '[6E]Bare Hands','[6F]Shield','[70]Knife','[71]Staff','[72]Spear','[73]Sword','[74]Axe','[75]Bow']
assert len(B) == 116, len(B)
apply('script/ff2/battle_msgs.json', dict(enumerate(B)))
