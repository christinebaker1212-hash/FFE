import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from apply import apply
# {07} = Maria's brother (party name insert); {10:02}-{13:02} = party/guest names.
# [{16:xx}{18:yy}] = a key word that can be learned (shown in brackets).
D = {
0:"The door is locked",
1:"{18:EF}: \"The password is [{16:0C}{18:F1}].\nRemember it well.\"",
2:"The wild rose is the crest of the kingdom of {18:2F}\n{18:2F}... ahh, what will become of {18:2F}?\nSomeone says they saw the captured people\nbeing gathered in {18:2F}...\nNow that I think of it, {11:02}'s older brother\n{07} is missing as well, isn't he.\nPerhaps he is in the town of {18:2F}.\n\nBut {18:2F} has now become a dangerous town\nwhere monsters prowl.\nIt won't be easy to get near it.\n",
3:"{18:EF}: \"That {18:01} is Scott's!\nIs he alive?!\"\n{10:02}: \"The prince was in the town of {18:2F}.\nHe entrusted this {18:01} to us, and then his strength gave out...\"\n{18:EF}: \"...Then that {18:01} is all he left behind...\nDid he say anything?\"\n{10:02}: \"...No, nothing...\nPlease take this {18:01}.\"\n{18:EF}: \"Please keep it yourself.\nIt is a {18:01} fit for one with courage.\nTo think you slipped into {18:2F} and came back...\nI underestimated your strength.\nPlease lend your strength to the rebel army.\nWe need strong warriors to obtain\nthe magic metal [{16:09}{18:F2}].\"\n",
4:"We lost the battle for {18:2F} because of the difference in equipment\nThe Empire's soldiers were using weapons\nand armor made of {18:04}.\n\nThe Empire has found {18:04} somewhere.\nI ordered a man named Josef, who lives in Salamand,\nto investigate, but there has been no word yet.\nWould you go to Salamand together with Minwu?",
5:"Minwu is a white wizard of great virtue.\nHe will surely be a help to you.\nPlease go to Salamand together with Minwu.",
6:"The Empire, too, suffered great losses in the battle\nfor {18:2F}. To make up for them, it is building\nthe [{16:01}{18:F3}] in Bafsk.",
7:"The {18:F3} is an enlarged [{16:09}{18:F5}]\nloaded with a great many weapons.\nThe Empire is making the people of Bafsk\nbuild the {18:F3}.",
8:"A man named Cid, who led the White Knights\nof {18:2F}, built an airship, but\nits allure stole his body and soul,\nand he left {18:2F}.\nNow he lives in the town of Poft, taking money\nfrom travelers to give them rides in his airship.\nThey say he pours every bit of that money into\nimproving the airship's performance.",
9:"So that is the {18:04}?!\nPlease take it to Tobul at the town's weapon shop,\n{18:EC} beg you. Ahh, now we can fight the Empire\non equal terms!!",
10:"The {18:EE} who oversees the building of the [{16:01}{18:F3}]\nseems to be a capable man. Fortunately, he has\nsuddenly been called back to Palamecia.\nNo doubt they're in a panic at having the {18:04} taken from them.",
11:"Our comrades in Bafsk say they have found\na secret passage that leads to the battleship.\nPlease destroy the battleship. Even just delaying\nits completion will do.\nWith your strength and {13:02}'s, I believe\nthere is nothing you cannot do.\n",
12:"{18:EF}: \"The great battleship's attack wounded\nmany people of the town. My father lost all\nheart, and it seems his illness has grown worse.\nFather himself says death is near...\"\n{11:02}: \"{13:02}, isn't there anything you can do?\"\n{13:02}: \"...All that live must die someday.\nBut saving those who suffer is {18:EC}'s duty.\n\n{18:EC} must stay here and treat the people.\nWe shall part ways here.\n{10:02}, destroy the great battleship\nwithout a moment's delay.\"\n    Parted with {13:02}\n",
13:"Thanks to Minwu, Father seems to be\nmuch more comfortable",
14:"{18:EF}: \"The great battleship's attack killed\nmany people. How are we to fight\nsomething like that? I wonder if anyone\nknows its weak point...\"",
15:"{18:EF}: \"I've heard that story from Scott\nand {18:EB}.\nThey say the door of Kashuon can only be opened by\nthe voice of one of the royal line or the clear tone of a bell.\nAnd that bell is hidden deep within\nthe cave of the snowfield and cannot be taken out.\nYou don't mean to go there?!\n\nAhh, if only {18:EB} were here, you would not\nhave to run such a risk!\nWherever could he have gone?\n\nIt can't be helped.\nIt seems all I can do is pray for your success.\nThe snowfield is like Josef's own backyard.\nYou should talk it over with him.\"",
16:"{18:EF}: \"The {18:08} is the symbol of\nKashuon, and it still burns on\nthe first floor of the castle. I have heard several\nstories about the flame from Scott and {18:EB}.\nFor instance, that the flame cannot be\ntransferred to an ordinary torch...\"\n{10:02}: \"With the {18:08}, we might\nbe able to destroy the great battleship.\"\n{18:EF}: \"Is that true!!\nPlease go at once.\nCid will surely take you to Kashuon.\nBut how will you bring the flame back, I wonder?\"",
17:"{18:EF}: \"My, {13:02}! It's been a long time.\nIt must have been terrible, your daughter\ncaptured by the Empire.\nPlease help {10:02} once again.\"",
18:"Please obtain the {18:04}\nwithout a moment's delay!",
19:"In exchange for that bell, Josef...........\nWith it, you can enter Castle Kashuon.\nEvery moment counts.\nFor your return, we'll come to pick you up in Cid's airship.",
20:"{18:EF}: \"{18:EB}! You are such a...\nIf you had been here, Josef would not have had to die!\"\n{18:EB}: \"{18:EF}, listen to me! {18:EC}...\"\n{18:EF}: \"I don't want to hear anything you have to say!\"",
21:"Now, quickly, let's escape!!",
22:"Ufufu...",
23:"{18:EF}: \"{10:02}, there is something I want to talk to you about...\"",
24:"{18:EF}: \"{10:02}! {11:02}! {12:02}!\nThank you for rescuing me.\nI hear you destroyed the great battleship as well.\nAhh, I have no words to thank you enough.\"",
25:"It's all right, {18:EC} am the real one.",
26:"My, {13:02}! And here I thought you'd vanished!!\nAs {18:EB} has planned, {18:EC} and the others will draw\nthe enemy's attention, and meanwhile\nyou will slip into Castle {18:2F}\nand strike down the enemy commander.\nIn Castle {18:2F}, go straight on from the entrance\nand you will come to the great hall.\nThe enemy should be there. Be careful.",
27:"{18:EF}: \"At last we have been able to come back here\nThis, too, is the result of everyone joining forces.\nI thank you all.\n\nOne thing that weighs on me is Minwu, who headed\nfor {18:F8}. There has been no word from him since.\nWould you go to [{16:01}{18:F8}]?\"\n",
28:"{18:F8} is the land of mages.\nWithout borrowing the power of their magic,\nit will be hard to defeat the Emperor.\n\nI hear a powerful magic is sealed\nin the tower of {18:F8}.\nIt seems that for that, the [{16:08}{18:FE}]\nis needed.",
29:"They say that long, long ago a passage to hell opened,\nand many monsters swarmed onto the surface.\nAt that time, by the power of that magic,\nthe monsters were driven back.",
}
apply('script/ff2/dialogue_b.json', D)
