"""Deterministic, original synthetic GIF fixtures; Pillow is a test-only tool."""
from pathlib import Path
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[1]/'test/fixtures'
root.mkdir(parents=True,exist_ok=True)
palette=[c for i in range(256) for c in ((i*17)%256,(i*43)%256,(i*97)%256)]
def frames(w,h,n,transparent=False):
 result=[]
 for t in range(n):
  im=Image.new('P',(w,h));im.putpalette(palette)
  im.putdata([((x//8+y//8+t*13)%255)+1 for y in range(h) for x in range(w)])
  ImageDraw.Draw(im).rectangle((t%(w//2+1),t%(h//2+1),w//2,h//2),fill=(t*7)%255+1)
  if transparent:ImageDraw.Draw(im).rectangle((0,0,5,5),fill=0)
  result.append(im)
 return result
for name,w,h,n,transparent in [('small-static',16,16,1,False),('small-animation',32,32,8,False),('large-canvas',512,512,3,False),('many-frames',24,24,100,False),('many-colors',128,128,10,False),('transparent',32,32,8,True)]:
 ims=frames(w,h,n,transparent);kw=dict(save_all=True,append_images=ims[1:],duration=[(i%5)*10 for i in range(n)],loop=2,disposal=2,comment=b'original synthetic gifsicle_flutter fixture',optimize=False,interlace=True)
 if transparent:kw['transparency']=0
 ims[0].save(root/(name+'.gif'),**kw)
# Explicit disposal previous / local palette / transparent animation.
ims=frames(24,24,3,True);ims[1].putpalette(palette[3:]+palette[:3]);ims[0].save(root/'disposal-previous.gif',save_all=True,append_images=ims[1:],duration=[0,10,30],loop=0,disposal=[1,2,3],transparency=0,optimize=False)
