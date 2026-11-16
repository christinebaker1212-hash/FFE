import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from apply import apply
D = {
0:" ",
1:"Leave everything you've got and we'll let you off with your lives\n\nWhat, you wanna fight! What a bunch of idiots\nBoys, let 'em have it!",
2:"We lose. Go on, do what you want with us!\n\n...Why ain't you killin' us?\n\n...You want us to fight the Empire with you!\nWith a bunch of outcasts like us...\n",
3:"Boys, to your posts!\nCome on, to Deist or to the ends of the earth,\nI'm followin' you!\n    Leila joined the party!!",
4:"{18:EF}: \"Minwu, can he be saved?\"\n\nMinwu: \"Yes, he will soon regain consciousness\nI sense a strong life force\"\n{18:EF}: \"When we were fleeing from {18:2F}, I found this boy\nlying covered in blood\nI thought that you would be able to save him\"\n",
5:"Minwu: \"This magic circle amplifies\nthe life force. Let us leave him in peace\"\n{18:EF}: \"I'm relieved. Now then, let us go\nto the council. Everyone should be gathered by now\nThe {18:F3} the Empire is building\nin Bafsk! Once it is completed,\nthe enemy's all-out attack will begin\nWe must do something!\"",
6:"{10:02}: \"Wh- where am I?\n\nAh! Is everyone safe?!\"",
7:"{07}!",
8:"{11:02}!",
9:"{12:02}!",
10:"{11:02}: \"{10:02}, you're alive!\n...Thank goodness... {18:EC}... (sniff)\"",
11:"{10:02}: \"{11:02}, {12:02}\nWhere's {07}?\"\n{12:02}: \"{18:ED} of {18:2F} saved us\n{07} not there\"\n{10:02}: \"I see... It's all right,\nhe's alive, I'm sure of it.\"\n",
12:"{18:EF}: \"So you've recovered. I'm glad\"\n{10:02}: \"{18:ED}, let {18:EC} and my friends join\nthe rebel army!\"\n{18:EF}: \"No, no! With your strength\nyou would only throw your lives away.\nGo home.\"\n{11:02}: \"{18:EC} and the others have no home anymore.\nOur parents too...\"\n{18:EF}: \"I'm sorry... I know!\nIf you like, live here in Altea. As long as you\nremember the password, you can live freely.\nThe password is {18:F1}. Don't forget it.\"",
13:"{07}: \"All right, {11:02}\"",
14:"It's no use!",
15:"{13:02}: \"Now, run while you can!\"\n{12:02}: \"Can't leave you behind\"\n{13:02}: \"Hurry... I can't... hold it any... longer\"",
16:"{13:02}: \"Take care... of... Nelly!\"\n\nAt last {13:02}'s strength gave out, and he was crushed beneath the rocks...\n{10:02}: \"{13:02}!!!\"",
17:"King of {18:2F}: \"{18:EB}, Minwu, {10:02}\nI have a request of you\"",
18:"King of {18:2F}: \"{18:EB}, you have grown strong\nI want you to take command of our army\nAnd help {18:EF}\"\n{13:02}: \"Yes, sire, with my life!\"\nKing of {18:2F}: \"Minwu... it is said that when crisis comes\nto the world, the seal of the {18:F9} will be broken\nI believe that time is now. What say you?\"\nMinwu: \"Yes, I shall go and break the seal\"\nKing of {18:2F}: \"{10:02}, go to Deist\nThe {18:FA} of Deist were slaughtered,\nbut there must surely be survivors\nThe power of the {18:FB} and the {18:FA} is something we need\"\nKing of {18:2F}: \"If all join their strength, surely\nthe day of victory will come\nI am counting on all three of you\"\n",
19:"King of {18:2F}: \"My daughter... take care of {18:EF}... ugh...\"",
}
apply('script/ff2/events.json', D)
