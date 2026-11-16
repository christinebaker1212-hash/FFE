"""Run two ROMs with identical inputs from the same start script; compare frames + WRAM."""
import sys, random, numpy as np
from drive import *
from cynes import NES
def setup(rom):
    s=[(0,1,600),(START,5,120),(A,5,60)]
    for c in range(4): s+=[(A,5,40),(A,5,30),(A,5,30),(A,5,30),(A,5,60),(0,1,0)]
    s+=[(START,5,200),(0,1,0),(A,5,300),(0,1,0),(A,5,300),(0,1,0)]
    for k in range(6): s+=[(A,5,200),(0,1,0)]
    return run(rom, s, 'x')
a=setup(sys.argv[1]); b=setup(sys.argv[2])
rng=random.Random(int(sys.argv[3]))
btns=[UP,DOWN,LEFT,RIGHT,A,A,B,START,UP,DOWN,LEFT,RIGHT]
first=None; frames=0
for i in range(int(sys.argv[4])):
    m=rng.choice(btns); hold=rng.randint(2,40); gap=rng.randint(0,20)
    for n in (a,b): n.controller=m
    fa=a.step(hold); fb=b.step(hold)
    for n in (a,b): n.controller=0
    fa=a.step(gap+1); fb=b.step(gap+1); frames+=hold+gap+1
    if not np.array_equal(fa,fb):
        first=frames; Image.fromarray(np.hstack([fa,fb])).save('diff.png'); break
wa=bytes(a[0x6000+k] for k in range(0x2000)); wb=bytes(b[0x6000+k] for k in range(0x2000))
ra=bytes(a[k] for k in range(0x800)); rb=bytes(b[k] for k in range(0x800))
print('ramdiff',[hex(k) for k in range(0x800) if ra[k]!=rb[k]][:20]); print('frames',frames,'first diff',first,'wram equal',wa==wb,'ram equal',ra==rb,'crash',a.has_crashed,b.has_crashed)
Image.fromarray(np.hstack([np.array(a.step(1)),np.array(b.step(1))])).save('end.png')
# frame-lag analysis after the first diff
fa_list=[np.array(a.step(1)) for _ in range(12)]
fb_list=[np.array(b.step(1)) for _ in range(12)]
for lag in range(-6,7):
    m=sum(np.array_equal(fa_list[i],fb_list[i+lag]) for i in range(12) if 0<=i+lag<12)
    print('lag',lag,'matches',m)
