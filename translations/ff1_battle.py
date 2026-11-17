import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from apply import apply
# Battle messages: most are predicates printed after a name.
B = {
 0:'HP recovered!', 1:'Armor went up', 2:'Became better at dodging attacks', 3:'Fell asleep',
 4:"The enemy's form stands out", 5:'Eyesight returned', 6:'Was silenced', 7:'Became resistant to lightning',
 8:'Was wrapped in darkness', 9:"Weapon's power increased", 10:'Movements slowed', 11:'Became resistant to fire',
 12:'Movement was sealed', 13:'The poison vanished', 14:'Got ready to flee', 15:'Became resistant to cold',
 16:'Broke the silence', 17:'Became quick', 18:'Became confused', 19:'Was poisoned', 20:'Death came',
 21:'Swallowed by a fissure!', 22:'Was paralyzed', 23:'Fully recovered', 24:'Became resistant to all magic',
 25:'Turned to stone and shattered!', 26:'Drew forth a magic sword', 27:'Was wrapped in a strange light',
 28:'Defense vanished', 29:'Time stopped', 30:'Was hurled into a rift in dimensions!', 31:'Life was taken...',
 32:'Had no effect', 33:'A chance to strike first!', 34:'The monsters strike first!', 35:"Can't escape!",
 36:'Ran away', 37:'Somehow got away...', 38:'Woke up!', 39:'Is asleep', 40:'Recovered!', 41:'Is paralyzed',
 42:' hits!', 43:'Critical hit!!', 44:"Can't use magic!", 45:' damage', 46:'Has turned to stone',
 47:'Level up!', 48:'Max HP', 49:' points', 50:'Strength', 51:'Agility', 52:'Intelligence', 53:'Vitality',
 54:'Luck', 55:' went up', 56:'Magic power', 57:"Gained next level's magic power!", 58:' went down',
 59:'were wiped out', 60:'The monsters ', 61:"'s party ", 62:'Dealt the finishing blow!!', 63:'Miss!',
 64:'    ', 65:'Stone', 66:'Poison', 67:'Darkness', 68:'Paralysis', 69:'Sleep', 70:'Silence', 71:'HP',
 72:'Experience up', 73:'No effect now', 74:'Is silenced', 75:'Began fighting among themselves',
 76:'Poison smoke envelops all', 77:'Nothing happened',
}
apply('script/ff1/battle_msgs.json', B)
apply('script/ff1/battle_cmds.json', {0:'Fight', 1:'Magic', 2:'Medicine', 3:'Items', 4:'Run'})
apply('script/ff1/title_menu.json', {0:'  Continue', 1:' Start Over', 2:' Message Speed'})
