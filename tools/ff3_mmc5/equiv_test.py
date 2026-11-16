import sys, random, numpy as np
from drive import *
from cynes import NES
a=NES(sys.argv[1]); b=NES(sys.argv[2])
rng=random.Random(int(sys.argv[3]))
btns=[UP,DOWN,LEFT,RIGHT,A,A,A,B,START,UP,DOWN,LEFT,RIGHT]
first=None; frames=0
for i in range(int(sys.argv[4])):
    m=rng.choice(btns); hold=rng.randint(2,40); gap=rng.randint(0,20)
    for n in (a,b): n.controller=m
    a.step(hold); b.step(hold)
    for n in (a,b): n.controller=0
    fa=a.step(gap+1); fb=b.step(gap+1); frames+=hold+gap+1
    if not np.array_equal(fa,fb):
        first=frames; Image.fromarray(np.hstack([fa,fb])).save('diff_%s.png'%sys.argv[3]); break
    if i%300==0: Image.fromarray(np.array(fa)).save('prog_%s_%d.png'%(sys.argv[3],i))
print('ramdiff',[hex(k) for k in range(0x800) if a[k]!=b[k] and not 0x100<=k<0x200][:20]); wa=bytes(a[0x6000+k] for k in range(0x2000)); wb=bytes(b[0x6000+k] for k in range(0x2000))
ra=bytes(a[k] for k in range(0x800)); rb=bytes(b[k] for k in range(0x800))
print('frames',frames,'first diff',first,'wram equal',wa==wb,'ram equal',ra==rb,'crash',a.has_crashed,b.has_crashed)
