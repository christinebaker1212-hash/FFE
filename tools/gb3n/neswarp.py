"""neswarp.py MAP OUT.png "F F F" [PRESSES] : the NES (cave.state) entering MAP through a poked entrance"""
import sys; sys.path.insert(0,'build/emu3')
from cynes import NES
import numpy as np
from PIL import Image
mid=int(sys.argv[1]); out=sys.argv[2]; shots=[int(x) for x in sys.argv[3].split()]
bits={'R':1,'L':2,'D':4,'U':8,'S':16,'E':32,'B':64,'A':128}
pr=[]
for p in (sys.argv[4].split() if len(sys.argv)>4 else []):
    f,k,h=p.split(':'); pr.append((int(f),sum(bits[c] for c in k),int(h)))
n=NES('/home/user/FFE/build/ff3_en.nes'); st=bytearray(open('build/ff3/cave.state','rb').read())
R=0x500A
st[R+0x700]=mid; st[R+0x45]=0x40; st[R+0xAB]=0x80
n.load(np.array(st,dtype=np.uint8))
ims=[]
for f in range(max(shots)+1):
    c=0
    for a,k,h in pr:
        if a<=f<a+h: c|=k
    n.controller=c
    fr=n.step(1)
    if f in shots: ims.append(Image.fromarray(fr.copy()))
s=bytes(n.save()); ram=s[R:R+0x800]
print('map',ram[0x48],'pos',(ram[0x29]+7)&63,(ram[0x2A]+7)&63)
sh=Image.new('RGB',(4*260,((len(ims)+3)//4)*244))
for i,im in enumerate(ims): sh.paste(im,((i%4)*260,(i//4)*244))
sh.save(out)
