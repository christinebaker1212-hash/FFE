import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from apply import apply
# Ending lines are centered on screen; the inserter recenters.
apply('script/ff2/ending.json', {
0:"The long battle has come to an end\nThe Emperor, Pandaemonium, the monsters...\nall of them have vanished without a trace\n\nPeace has returned to the world...\n\nThe people will heal the scars of battle\nand forget the days of suffering\nBut they will never forget\nthat there were young people who saved the world\n",
1:"to join their companions\nFor their friendship and their memories\nshall never fade away...\n",
2:"ENDING\n1 Four young people living here in the Kingdom of Finn\n2 lost their parents to the enemy's attack\n3 and kept fleeing from their relentless pursuers...",
3:" " * 19,
})
