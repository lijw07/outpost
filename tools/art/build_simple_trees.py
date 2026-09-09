"""Normalize the simplified ImageGen sheet and derive exact complementary tree layers."""
from PIL import Image,ImageDraw
import numpy as np
CONFIG=[('oak',(104,128),(0,0,610,825),78,108,52),('birch',(80,144),(610,0,1024,825),94,124,40),('young_oak',(72,104),(0,825,540,1536),63,86,36),('deadwood',(88,136),(540,825,1024,1536),78,112,42)]
def build(pack):
 source=Image.open(pack/'source/trees_simple.png').convert('RGBA');a=np.array(source);a[:,:,3]=np.where(a[:,:,3]>=220,255,0);a[a[:,:,3]==0]=0;source=Image.fromarray(a)
 whole={}
 for name,size,region,top,cut,cx in CONFIG:
  cell=source.crop(region);cell=cell.crop(cell.getbbox());scale=min((size[0]-4)/cell.width,(size[1]-4)/cell.height);cell=cell.resize((round(cell.width*scale),round(cell.height*scale)),Image.Resampling.NEAREST)
  out=Image.new('RGBA',size);out.paste(cell,((size[0]-cell.width)//2,size[1]-2-cell.height));whole[name]=out
 # Reserve bark/cream entries explicitly so canopy pixels cannot crowd out birch whites.
 colors=[(28,50,29),(44,78,40),(65,100,44),(89,127,50),(127,155,64),(154,176,80),
         (43,32,24),(56,38,28),(78,52,34),(103,74,53),(135,104,77),(169,134,92),
         (200,168,121),(157,146,121),(214,195,163),(249,235,207)]
 pal=Image.new('P',(1,1));pal.putpalette([v for c in colors for v in c]*16)
 meta={}
 for name,size,region,top,cut,cx in CONFIG:
  image=whole[name];alpha=image.getchannel('A');image=image.convert('RGB').quantize(palette=pal,dither=Image.Dither.NONE).convert('RGBA');image.putalpha(alpha)
  a=np.array(image);a[a[:,:,3]==0]=0;image=Image.fromarray(a)
  a=np.array(image);h,w=a.shape[:2];root=np.array([w//2,h-2]);row=a[cut-1,:,3]>0
  # Measure the visible shaft at the root cut, and keep the same centerline throughout.
  if not row[cx]:cx=int(np.flatnonzero(row)[len(np.flatnonzero(row))//2])
  lo=hi=cx
  while lo>0 and row[lo-1]:lo-=1
  while hi<w-1 and row[hi+1]:hi+=1
  center=(lo+hi)/2;diameter=hi-lo+1
  masks={};shaft=np.zeros((h,w),bool)
  for y in range(top,cut):
   width=max(2,round(diameter*(.8+.2*(y-top)/max(1,cut-top-1))));left=round(center-(width-1)/2);shaft[y,left:left+width]=True
  shaft &= a[:,:,3]>0;roots=np.zeros((h,w),bool);roots[cut:]=a[cut:,:,3]>0
  masks={'trunk_joined':shaft,'stump_joined':roots,'crown':(a[:,:,3]>0)&~shaft&~roots}
  layers={};origins={};assembled=Image.new('RGBA',size)
  for state,mask in masks.items():
   b=np.zeros_like(a);b[mask]=a[mask];part=Image.fromarray(b);box=part.getbbox();assert box
   layer=Image.new('RGBA',(box[2]-box[0]+8,box[3]-box[1]+8));layer.paste(part.crop(box),(4,4));layers[state]=layer;origins[state]=np.array([box[0]-4,box[1]-4]);assembled.alpha_composite(layer,tuple(origins[state]))
  assert assembled.tobytes()==image.tobytes(),name+' standing assembly changed'
  # Reuse the palette's wood colors for simple, chunky cut faces.
  samples={'oak':[(90,56,32),(178,123,73),(126,83,48)],'birch':[(86,74,54),(228,210,177),(162,143,114)],'young_oak':[(90,56,32),(178,123,73),(126,83,48)],'deadwood':[(74,58,45),(166,140,112),(112,91,70)]}[name]
  palette=np.array(pal.getpalette()[:48]).reshape(-1,3)
  wood=[tuple(int(v) for v in palette[np.argmin(((palette.astype(float)-c)**2).sum(1))])+(255,) for c in samples]
  def cap(im,x,y,width):
   d=ImageDraw.Draw(im);r=max(1,width//2);rect=(round(x)-r,y-2,round(x)+r,y+2);d.ellipse(rect,fill=wood[0]);d.ellipse((rect[0]+1,y-1,rect[2]-1,y+1),fill=wood[1]);d.line((round(x)-r+2,y,round(x)+r-2,y),fill=wood[2])
  stump=layers['stump_joined'].copy();cap(stump,center-origins['stump_joined'][0],4,diameter)
  trunk=layers['trunk_joined'].copy();cap(trunk,center-origins['trunk_joined'][0],4,round(diameter*.8));cap(trunk,center-origins['trunk_joined'][0],trunk.height-5,diameter)
  layers.update(stump=stump,trunk=trunk,standing=image,log=trunk.transpose(Image.Transpose.ROTATE_270))
  for state,im in layers.items():im.resize((im.width*2,im.height*2),Image.Resampling.NEAREST).save(pack/'trees'/f'{name}_{state}.png')
  pivot=(np.array([center,cut])-root)*2;crown=layers['crown'];cp=(origins['crown']+np.array([crown.width/2,crown.height-2])-root)*2
  meta[name]={'revision':'simple-16color-v1','standing_size':[size[0]*2,size[1]*2],'trunk_base_y':float(pivot[1]),'pivot_x':float(pivot[0]),'crown_base_y':float(cp[1]),'crown_x':float(cp[0]-pivot[0]),'stump_offset':((origins['stump_joined']-root)*2).tolist(),'trunk_offset':((origins['trunk_joined']-root)*2-pivot).tolist(),'cut_diameter':diameter*2,'source_region':list(region),'split_rows':[top*2,cut*2]}
 print('PASS: four simplified trees share 16 colors; all standing layers reconstruct exactly; exports use a consistent 2px grid.')
 return meta
