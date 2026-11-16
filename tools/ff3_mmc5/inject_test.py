"""Run two ROMs with identical random input until both are in field/battle NMI mode,
then inject a call to a given routine in both and compare frames."""
import sys, random, numpy as np
from drive import *
from cynes import NES
romA, romB, seed, iters, bank, addr = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5],16), int(sys.argv[6],16)
a=NES(romA); b=NES(romB); rng=random.Random(seed)
btns=[UP,DOWN,LEFT,RIGHT,A,A,A,B,START,UP,DOWN,LEFT,RIGHT]
for i in range(iters):
    m=rng.choice(btns); h=rng.randint(2,40); g=rng.randint(1,20)
    for n in (a,b): n.controller=m; n.step(h); n.controller=0; n.step(g)
# wait until NMI trampoline is the field/battle one (JMP $FB57)
for k in range(600):
    if all(n[0x100]==0x4C and n[0x101]==0x57 and n[0x102]==0xFB and n[0xA9]==0 and n[0xAA]==0 for n in (a,b)): break
    for n in (a,b): n.step(1)
code=[0x68,0x68,0x68,0x58,                 # PLA x3 (drop NMI frame), CLI
      0xA9,0x57,0x8D,0x01,0x01,0xA9,0xFB,0x8D,0x02,0x01,   # restore trampoline
      0xA9,bank,0x20,0x03,0xFF,            # LDA #bank / JSR $FF03 (R6=bank, R7=bank+1)
      0x20,addr&0xFF,addr>>8,              # JSR addr
      0x4C,0xF6,0x07]                      # spin: JMP $07F8 (code at $07E0, len 25)
assert len(code)==25
for n in (a,b):
    for k,v in enumerate(code): n[0x7E0+k]=v
    n[0x101]=0xE0; n[0x102]=0x07           # NMI -> JMP $07E0
frames=0; first=None; shots=[]
for f in int(sys.argv[7]) * [1]:
    fa=a.step(1); fb=b.step(1); frames+=1
    if frames % 20 == 0: shots.append(np.hstack([np.array(fa),np.array(fb)]))
    if first is None and not np.array_equal(fa,fb):
        first=frames; Image.fromarray(np.hstack([np.array(fa),np.array(fb)])).save('inj_diff.png')
print('frames',frames,'first diff',first,'crash',a.has_crashed,b.has_crashed)
im=Image.new('RGB',(516,240*min(len(shots),6)))
for i,s in enumerate(shots[:6]): im.paste(Image.fromarray(s),(0,240*i))
im.save('inj.png')
