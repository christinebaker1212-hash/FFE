"""Drive a ROM with a button script and save screenshots.
script: list of (button_mask, frames_held, frames_after) ; saves frame at each 'shot'."""
import sys
from cynes import NES
from PIL import Image
import numpy as np
RIGHT,LEFT,DOWN,UP,START,SEL,B,A=1,2,4,8,16,32,64,128
def run(rom, script, out_prefix):
    n=NES(rom); shots=[]
    for item in script:
        if item[0]=='shot':
            f=n.step(1); shots.append(np.array(f)); continue
        mask,hold,after=item
        n.controller=mask; n.step(hold); n.controller=0; n.step(after)
    if n.has_crashed: print('CRASHED')
    if not shots: return n
    im=Image.new('RGB',(260*len(shots),240))
    for i,s in enumerate(shots): im.paste(Image.fromarray(s),(i*260,0))
    im.save(out_prefix+'.png'); return n
