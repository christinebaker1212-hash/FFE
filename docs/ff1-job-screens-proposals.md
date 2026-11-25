# FF1 native build: party / job / name screens, proposals (2026-11-25)

Owner (2026-11-25): "Let's Nintendo-ify the Job selection and Job Picker screen. Your suggestions?"
Looked at in SameBoy on Color and on the plain Game Boy (White windows): the party screen (four boxes), the
job list, name entry and the "OK to begin with this party?" question. Same yardstick as
`docs/ff1-mode-menu-audit.md`: Nintendo's own Game Boy / Color RPGs (Pokemon's name entry and party
screens), Final Fantasy I & II: Dawn of Souls (Nintendo published it in North America: its party creation
shows each class's starting stats), the owner's layout direction (one line per member, full-width windows),
and the rules this port already keeps (header windows, the hand inside its window).

## What it does now
- Party screen: four 10 x 9 boxes filling the screen, each with the job's picture, the job's name (two
  lines for "Red / Magician" and the others), the member's name under it. No header, no hint of what to
  do. A on a box: the job list, then name entry; when all four have names, "OK to begin with this party?".
- Job list: the six jobs in a 2 x 3 grid, picture over name; the hand on the left screen edge.
- Name entry: a top window with the picture, the job, "SELECT: abc" and the name so far ("-" when empty);
  the letters below. A types, B deletes (on an empty name: back to the jobs), START types a preset name
  (owner, 2026-11-25), then finishes; the sixth letter finishes by itself.

## Findings
1. **No header and no instruction** on the party screen and the job list; every other screen has a header.
2. **Text jumps around in the boxes:** two-line job names push the member's name down a row, so the four
   names sit at different heights ("Red Magician / Yura" vs "Thief / (gap) / Curtis").
3. **An unnamed member shows nothing**: the player cannot tell which members still need a name.
4. **The hand sits on frames**: on the party boxes it covers the box's corner and the picture; in the job
   list it is cut off by the screen edge.
5. **The cursor does not move on** after a member is named; FF1 itself takes the four in turn.
6. **The job list says nothing about the jobs.** Dawn of Souls shows each class's starting stats; here
   the player picks from pictures and names only. The starting stats are already in the build (from the
   user's ROM).
7. **Name entry hides its limit**: "-" gives no hint that names hold six letters, and the sixth letter
   ends the entry at once, so a typo in it cannot be fixed. Nintendo's name entry (Pokemon) shows every
   slot ("DUNE__"), has an END on the grid and puts START on END.
8. **"SELECT: abc"** is a key hint in a title row; Nintendo shows the cases as tabs ("ABC abc 123").

## Proposals (pick per screen)

### Party screen
**P-A (recommended): one line per member, as the main menu.** A "Light Warriors" header, then the four
members in one window, each with its picture, the job on one line and the name below it; a hint row at the
bottom. Every job name fits on one line, every name sits at the same place, and the hand points at the
picture inside the window, as on the main menu and Formation.
```
+------------------+
|  Light Warriors  |
+------------------+
|> PP Warrior      |
|  PP ------       |
|  PP              |
|  PP Thief        |
|  PP Curtis       |
|  PP              |
|  PP Monk         |
|  PP ------       |
|  PP              |
|  PP Red Magician |
|  PP Yura         |
|  PP              |
+------------------+
| A: Job  START: OK|   (hint row; "START: OK" once all four are named)
```
**P-B: keep the four boxes, fixed.** Job always on two rows (one-row names get a blank second row), name
always on the box's last text row, "------" for no name, the hand inside the box beside the job's name.
No room for a header (the boxes fill the 18 rows).

Either way: "------" for a member with no name yet (finding 3), the cursor moves to the next member with no
name after one is named (5), and after the fourth the question comes as now.

### Job picker
**K-A (recommended): pictures in a row, the chosen job described below** (Dawn of Souls' idea):
```
+------------------+
|   Choose a Job   |
+------------------+
| PP PP PP PP PP PP|   the six pictures; the highlighted one in its victory pose
|        ^^        |   (a small arrow under it), Left / Right to choose
+------------------+
| Red Magician     |
| Sword and spells |   one line of our own about the job
| of both kinds.   |
| HP 30  Str 10    |   starting stats from the user's ROM
| Agi 10 Int 10    |
| Vit 5  Luck 5    |
+------------------+
```
**K-B: the current 2 x 3 grid, with a stats window** instead of the bottom row of jobs: the grid becomes 3
x 2 (pictures over short names), the highlighted job's stats below. Less change, less room for text.

Either way: the hand (or arrow) inside the window (finding 4), and the member's current job highlighted
when the list opens (as now).

### Name entry
**N (recommended as a set):**
- six slots shown as "Yura__" with the next slot marked (finding 7);
- "END" on the grid; START moves the hand to END (Nintendo) and, with no name yet, still types a preset
  name first (the owner's preset feature kept);
- the sixth letter moves the hand to END instead of finishing, so B can still fix it;
- the cases as tabs above the grid ("ABC abc 123", the chosen one highlighted; SELECT still switches);
- the top row reads "Name the Red Magician" instead of the job alone.

## Not changed by any of these
The jobs, their order, the default party (Warrior / Thief / Monk / Red Magician), the preset names, the
"OK to begin with this party?" question and what Yes / No / B do.
