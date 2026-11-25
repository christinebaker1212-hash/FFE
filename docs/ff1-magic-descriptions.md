# FF1 native: magic shop spell descriptions (two proposals, 2026-11-25)

Owner: a description for each spell in the magic shops, shown at once while the hand is on it, at most
four lines (18 columns: the speech window's text area). Two formats below, all 64 spells each;
the owner picks one. Numbers come from the spell data in the ROM as this build uses it (damage and
healing: the effectivity E gives E to 2E; weakness 1.5x). Field use: the spells the main menu casts.

Note: Shapera's data (as FF1's, a known FF1 bug) raises the enemies' evasion instead of lowering it;
both lists describe what it is meant to do. Fixing that is a separate choice (marked *).

## Format A (the owner's): kind of magic / short description / target

```
L1 W Cure              L1 W Dia               L1 W Protes            L1 W Blink          
+------------------+   +------------------+   +------------------+   +------------------+
|White magic       |   |White magic       |   |White magic       |   |White magic       |
|Restores 16-32 HP.|   |Holy damage 20-40 |   |Raises defense    |   |Raises evasion    |
|Target: one ally  |   |to undead foes.   |   |by 8.             |   |by 80.            |
|                  |   |Target: all foes  |   |Target: one ally  |   |Target: self      |
+------------------+   +------------------+   +------------------+   +------------------+

L1 B Fire              L1 B Sleep             L1 B Shape             L1 B Thunder        
+------------------+   +------------------+   +------------------+   +------------------+
|Black magic       |   |Black magic       |   |Black magic       |   |Black magic       |
|Fire damage 10-20.|   |Puts foes to      |   |Lowers evasion    |   |Lightning damage  |
|Target: one foe   |   |sleep.            |   |by 20.            |   |10-20.            |
|                  |   |Target: all foes  |   |Target: one foe   |   |Target: one foe   |
+------------------+   +------------------+   +------------------+   +------------------+

L2 W Blindna           L2 W Silence           L2 W Thunder Barrier   L2 W Invisible      
+------------------+   +------------------+   +------------------+   +------------------+
|White magic       |   |White magic       |   |White magic       |   |White magic       |
|Cures Blind.      |   |Seals foes' magic.|   |Halves lightning  |   |Raises evasion    |
|Target: one ally  |   |Target: all foes  |   |damage.           |   |by 40.            |
|                  |   |                  |   |Target: all allies|   |Target: one ally  |
+------------------+   +------------------+   +------------------+   +------------------+

L2 B Blizzard          L2 B Darkness          L2 B Strike            L2 B Slow           
+------------------+   +------------------+   +------------------+   +------------------+
|Black magic       |   |Black magic       |   |Black magic       |   |Black magic       |
|Ice damage 20-40. |   |Blinds foes.      |   |Raises attack     |   |Cuts foes'        |
|Target: one foe   |   |Target: all foes  |   |by 14.            |   |attacks per turn. |
|                  |   |                  |   |Target: one ally  |   |Target: all foes  |
+------------------+   +------------------+   +------------------+   +------------------+

L3 W Cura              L3 W Adia              L3 W Fire Barrier      L3 W Heal           
+------------------+   +------------------+   +------------------+   +------------------+
|White magic       |   |White magic       |   |White magic       |   |White magic       |
|Restores 33-66 HP.|   |Holy damage 40-80 |   |Halves fire       |   |Restores 12-24 HP.|
|Target: one ally  |   |to undead foes.   |   |damage.           |   |Target: all allies|
|                  |   |Target: all foes  |   |Target: all allies|   |                  |
+------------------+   +------------------+   +------------------+   +------------------+

L3 B Fira              L3 B Hold              L3 B Thundara          L3 B Shapera *      
+------------------+   +------------------+   +------------------+   +------------------+
|Black magic       |   |Black magic       |   |Black magic       |   |Black magic       |
|Fire damage 30-60.|   |Paralyzes a foe.  |   |Lightning damage  |   |Lowers evasion    |
|Target: all foes  |   |Target: one foe   |   |30-60.            |   |by 20.            |
|                  |   |                  |   |Target: all foes  |   |Target: all foes  |
+------------------+   +------------------+   +------------------+   +------------------+

L4 W Poisona           L4 W Fear              L4 W Cold Barrier      L4 W Vocal          
+------------------+   +------------------+   +------------------+   +------------------+
|White magic       |   |White magic       |   |White magic       |   |White magic       |
|Cures Poison.     |   |Frightens foes    |   |Halves ice        |   |Cures Silence.    |
|Target: one ally  |   |so they flee.     |   |damage.           |   |Target: one ally  |
|                  |   |Target: all foes  |   |Target: all allies|   |                  |
+------------------+   +------------------+   +------------------+   +------------------+

L4 B Sleepra           L4 B Haste             L4 B Confuse           L4 B Blizzara       
+------------------+   +------------------+   +------------------+   +------------------+
|Black magic       |   |Black magic       |   |Black magic       |   |Black magic       |
|Puts a foe to     |   |Doubles attacks   |   |Confuses foes.    |   |Ice damage 40-80. |
|sleep.            |   |per turn.         |   |Target: all foes  |   |Target: all foes  |
|Target: one foe   |   |Target: one ally  |   |                  |   |                  |
+------------------+   +------------------+   +------------------+   +------------------+

L5 W Curada            L5 W Raise             L5 W Dadia             L5 W Heala          
+------------------+   +------------------+   +------------------+   +------------------+
|White magic       |   |White magic       |   |White magic       |   |White magic       |
|Restores 66-132   |   |Brings a fallen   |   |Holy damage 60-120|   |Restores 48-96 HP.|
|HP.               |   |ally back to life.|   |to undead foes.   |   |Target: all allies|
|Target: one ally  |   |Target: one ally  |   |Target: all foes  |   |                  |
+------------------+   +------------------+   +------------------+   +------------------+

L5 B Firaga            L5 B Clouda            L5 B Teleport          L5 B Raslow         
+------------------+   +------------------+   +------------------+   +------------------+
|Black magic       |   |Black magic       |   |Black magic       |   |Black magic       |
|Fire damage       |   |Poison gas that   |   |Returns to the    |   |Cuts a foe's      |
|50-100.           |   |can kill foes.    |   |floor above.      |   |attacks per turn. |
|Target: all foes  |   |Target: all foes  |   |Target: all allies|   |Target: one foe   |
+------------------+   +------------------+   +------------------+   +------------------+

L6 W Stona             L6 W Escape Teleport   L6 W Protea            L6 W Invisia        
+------------------+   +------------------+   +------------------+   +------------------+
|White magic       |   |White magic       |   |White magic       |   |White magic       |
|Cures Stone.      |   |Leaves the        |   |Raises defense    |   |Raises evasion    |
|Target: one ally  |   |dungeon at once.  |   |by 12.            |   |by 40.            |
|                  |   |Target: all allies|   |Target: all allies|   |Target: all allies|
+------------------+   +------------------+   +------------------+   +------------------+

L6 B Thundaga          L6 B Death             L6 B Quake             L6 B Stun           
+------------------+   +------------------+   +------------------+   +------------------+
|Black magic       |   |Black magic       |   |Black magic       |   |Black magic       |
|Lightning damage  |   |Can kill a foe    |   |Earthquake that   |   |Paralyzes a foe   |
|60-120.           |   |outright.         |   |can kill foes.    |   |under 300 HP.     |
|Target: all foes  |   |Target: one foe   |   |Target: all foes  |   |Target: one foe   |
+------------------+   +------------------+   +------------------+   +------------------+

L7 W Curaga            L7 W Gadia             L7 W Magic Barrier     L7 W Raheala        
+------------------+   +------------------+   +------------------+   +------------------+
|White magic       |   |White magic       |   |White magic       |   |White magic       |
|Restores all HP   |   |Holy damage 80-160|   |Guards against    |   |Restores 48-96 HP.|
|and cures ills.   |   |to undead foes.   |   |death and status. |   |Target: all allies|
|Target: one ally  |   |Target: all foes  |   |Target: all allies|   |                  |
+------------------+   +------------------+   +------------------+   +------------------+

L7 B Blizzaga          L7 B Break             L7 B Saber             L7 B Blind          
+------------------+   +------------------+   +------------------+   +------------------+
|Black magic       |   |Black magic       |   |Black magic       |   |Black magic       |
|Ice damage 70-140.|   |Turns a foe to    |   |Raises attack and |   |Blinds a foe      |
|Target: all foes  |   |stone.            |   |accuracy.         |   |under 300 HP.     |
|                  |   |Target: one foe   |   |Target: self      |   |Target: one foe   |
+------------------+   +------------------+   +------------------+   +------------------+

L8 W Arise             L8 W Holy              L8 W All Barrier       L8 W Dispel         
+------------------+   +------------------+   +------------------+   +------------------+
|White magic       |   |White magic       |   |White magic       |   |White magic       |
|Revives an ally   |   |Holy damage       |   |Guards against    |   |Strips a foe's    |
|with full HP.     |   |80-160.           |   |every element.    |   |resistances.      |
|Target: one ally  |   |Target: all foes  |   |Target: one ally  |   |Target: one foe   |
+------------------+   +------------------+   +------------------+   +------------------+

L8 B Flare             L8 B Stop              L8 B Dejon             L8 B Kill           
+------------------+   +------------------+   +------------------+   +------------------+
|Black magic       |   |Black magic       |   |Black magic       |   |Black magic       |
|Damage 100-200,   |   |Stops foes in     |   |Sends foes out of |   |Kills a foe       |
|no element.       |   |time.             |   |time.             |   |under 300 HP.     |
|Target: all foes  |   |Target: all foes  |   |Target: all foes  |   |Target: one foe   |
+------------------+   +------------------+   +------------------+   +------------------+

```

## Format B (mine): what it does / who and when / one note

Line 1 says what happens with its number (the thing you compare when buying); line 2 who it reaches
and when it can be cast (battle, field only, any time); line 3, only when useful, the condition or
catch (undead only, 300 HP limit, weakness, lasts the battle). The spell's name and level are on
the list row already, so the window spends no line on them; most entries take three lines.

```
L1 W Cure              L1 W Dia               L1 W Protes            L1 W Blink          
+------------------+   +------------------+   +------------------+   +------------------+
|HP +16-32         |   |Holy 20-40 dmg    |   |Defense +8        |   |Evasion +80       |
|1 ally, any time  |   |All foes, battle  |   |1 ally, battle    |   |Self, battle      |
|                  |   |Undead only       |   |Lasts the battle  |   |Lasts the battle  |
|                  |   |                  |   |                  |   |                  |
+------------------+   +------------------+   +------------------+   +------------------+

L1 B Fire              L1 B Sleep             L1 B Shape             L1 B Thunder        
+------------------+   +------------------+   +------------------+   +------------------+
|Fire 10-20 dmg    |   |Sleep             |   |Evasion -20       |   |Bolt 10-20 dmg    |
|1 foe, battle     |   |All foes, battle  |   |1 foe, battle     |   |1 foe, battle     |
|x1.5 if weak      |   |Skips its turns   |   |Easier to hit     |   |x1.5 if weak      |
|                  |   |                  |   |                  |   |                  |
+------------------+   +------------------+   +------------------+   +------------------+

L2 W Blindna           L2 W Silence           L2 W Thunder Barrier   L2 W Invisible      
+------------------+   +------------------+   +------------------+   +------------------+
|Cures Blind       |   |Silence           |   |Resist lightning  |   |Evasion +40       |
|1 ally, battle    |   |All foes, battle  |   |Party, battle     |   |1 ally, battle    |
|                  |   |No more spells    |   |Halves bolt dmg   |   |Lasts the battle  |
|                  |   |                  |   |                  |   |                  |
+------------------+   +------------------+   +------------------+   +------------------+

L2 B Blizzard          L2 B Darkness          L2 B Strike            L2 B Slow           
+------------------+   +------------------+   +------------------+   +------------------+
|Ice 20-40 dmg     |   |Blind             |   |Attack +14        |   |Fewer attacks     |
|1 foe, battle     |   |All foes, battle  |   |1 ally, battle    |   |All foes, battle  |
|x1.5 if weak      |   |Attacks miss more |   |Lasts the battle  |   |Fewer hits a turn |
|                  |   |                  |   |                  |   |                  |
+------------------+   +------------------+   +------------------+   +------------------+

L3 W Cura              L3 W Adia              L3 W Fire Barrier      L3 W Heal           
+------------------+   +------------------+   +------------------+   +------------------+
|HP +33-66         |   |Holy 40-80 dmg    |   |Resist fire       |   |HP +12-24 each    |
|1 ally, any time  |   |All foes, battle  |   |Party, battle     |   |Party, any time   |
|                  |   |Undead only       |   |Halves fire dmg   |   |                  |
|                  |   |                  |   |                  |   |                  |
+------------------+   +------------------+   +------------------+   +------------------+

L3 B Fira              L3 B Hold              L3 B Thundara          L3 B Shapera *      
+------------------+   +------------------+   +------------------+   +------------------+
|Fire 30-60 dmg    |   |Paralysis         |   |Bolt 30-60 dmg    |   |Evasion -20       |
|All foes, battle  |   |1 foe, battle     |   |All foes, battle  |   |All foes, battle  |
|x1.5 if weak      |   |Cannot act        |   |x1.5 if weak      |   |Easier to hit     |
|                  |   |                  |   |                  |   |                  |
+------------------+   +------------------+   +------------------+   +------------------+

L4 W Poisona           L4 W Fear              L4 W Cold Barrier      L4 W Vocal          
+------------------+   +------------------+   +------------------+   +------------------+
|Cures Poison      |   |Fear              |   |Resist ice        |   |Cures Silence     |
|1 ally, any time  |   |All foes, battle  |   |Party, battle     |   |1 ally, battle    |
|                  |   |Foes may run      |   |Halves ice dmg    |   |Can cast again    |
|                  |   |                  |   |                  |   |                  |
+------------------+   +------------------+   +------------------+   +------------------+

L4 B Sleepra           L4 B Haste             L4 B Confuse           L4 B Blizzara       
+------------------+   +------------------+   +------------------+   +------------------+
|Sleep             |   |Attacks x2        |   |Confusion         |   |Ice 40-80 dmg     |
|1 foe, battle     |   |1 ally, battle    |   |All foes, battle  |   |All foes, battle  |
|Surer than Sleep  |   |Lasts the battle  |   |Acts at random    |   |x1.5 if weak      |
|                  |   |                  |   |                  |   |                  |
+------------------+   +------------------+   +------------------+   +------------------+

L5 W Curada            L5 W Raise             L5 W Dadia             L5 W Heala          
+------------------+   +------------------+   +------------------+   +------------------+
|HP +66-132        |   |Revive, 1 HP      |   |Holy 60-120 dmg   |   |HP +48-96 each    |
|1 ally, any time  |   |1 ally, field only|   |All foes, battle  |   |Party, any time   |
|                  |   |                  |   |Undead only       |   |                  |
|                  |   |                  |   |                  |   |                  |
+------------------+   +------------------+   +------------------+   +------------------+

L5 B Firaga            L5 B Clouda            L5 B Teleport          L5 B Raslow         
+------------------+   +------------------+   +------------------+   +------------------+
|Fire 50-100 dmg   |   |Instant death     |   |Up one floor      |   |Fewer attacks     |
|All foes, battle  |   |All foes, battle  |   |Party, field only |   |1 foe, battle     |
|x1.5 if weak      |   |Poison-proof: safe|   |Dungeons only     |   |Fewer hits a turn |
|                  |   |                  |   |                  |   |                  |
+------------------+   +------------------+   +------------------+   +------------------+

L6 W Stona             L6 W Escape Teleport   L6 W Protea            L6 W Invisia        
+------------------+   +------------------+   +------------------+   +------------------+
|Cures Stone       |   |Exit dungeon      |   |Defense +12 each  |   |Evasion +40 each  |
|1 ally, field only|   |Party, field only |   |Party, battle     |   |Party, battle     |
|                  |   |Back to the map   |   |Lasts the battle  |   |Lasts the battle  |
|                  |   |                  |   |                  |   |                  |
+------------------+   +------------------+   +------------------+   +------------------+

L6 B Thundaga          L6 B Death             L6 B Quake             L6 B Stun           
+------------------+   +------------------+   +------------------+   +------------------+
|Bolt 60-120 dmg   |   |Instant death     |   |Instant death     |   |Paralysis         |
|All foes, battle  |   |1 foe, battle     |   |All foes, battle  |   |1 foe, battle     |
|x1.5 if weak      |   |Death-proof: safe |   |Fliers are safe   |   |Foe under 300 HP  |
|                  |   |                  |   |                  |   |                  |
+------------------+   +------------------+   +------------------+   +------------------+

L7 W Curaga            L7 W Gadia             L7 W Magic Barrier     L7 W Raheala        
+------------------+   +------------------+   +------------------+   +------------------+
|HP to full        |   |Holy 80-160 dmg   |   |Resist status     |   |HP +48-96 each    |
|1 ally, any time  |   |All foes, battle  |   |Party, battle     |   |Party, any time   |
|Cures ailments    |   |Undead only       |   |And death, quake  |   |                  |
|                  |   |                  |   |                  |   |                  |
+------------------+   +------------------+   +------------------+   +------------------+

L7 B Blizzaga          L7 B Break             L7 B Saber             L7 B Blind          
+------------------+   +------------------+   +------------------+   +------------------+
|Ice 70-140 dmg    |   |Stone             |   |Attack +16        |   |Blind             |
|All foes, battle  |   |1 foe, battle     |   |Self, battle      |   |1 foe, battle     |
|x1.5 if weak      |   |Gone for good     |   |And accuracy      |   |Foe under 300 HP  |
|                  |   |                  |   |                  |   |                  |
+------------------+   +------------------+   +------------------+   +------------------+

L8 W Arise             L8 W Holy              L8 W All Barrier       L8 W Dispel         
+------------------+   +------------------+   +------------------+   +------------------+
|Revive, full HP   |   |Holy 80-160 dmg   |   |Resist all        |   |Resists removed   |
|1 ally, field only|   |All foes, battle  |   |1 ally, battle    |   |1 foe, battle     |
|                  |   |No element        |   |Every element     |   |Then strike hard  |
|                  |   |                  |   |                  |   |                  |
+------------------+   +------------------+   +------------------+   +------------------+

L8 B Flare             L8 B Stop              L8 B Dejon             L8 B Kill           
+------------------+   +------------------+   +------------------+   +------------------+
|100-200 dmg       |   |Paralysis         |   |Instant death     |   |Instant death     |
|All foes, battle  |   |All foes, battle  |   |All foes, battle  |   |1 foe, battle     |
|No element        |   |Time magic        |   |Time magic        |   |Foe under 300 HP  |
|                  |   |                  |   |                  |   |                  |
+------------------+   +------------------+   +------------------+   +------------------+

```
