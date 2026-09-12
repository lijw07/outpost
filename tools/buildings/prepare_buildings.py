import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
all_buildings=[]

def building(name,title,w,d,wall,floor='floor_wood',levels=1,pitched=False):
 b={'id':name,'title':title,'width':w,'depth':d,'levels':levels,'pitched':pitched,'pieces':[],'rooms':[],'doors':[],'floors':[],'roof_tiles':[],'signs':[],'entry':[w/2-1,0,-.125]}
 b['wall']=wall;b['default_floor']=floor;all_buildings.append(b);return b

def p(b,id,x,z,y=0,r=0,level=0,group='Furniture',name=None):
 b['pieces'].append({'id':id,'position':[x,y+level*4,z],'rotation':r,'level':level,'group':group,'name':name or id})
 if id=='doorway_wood':b['doors'].append([x,y+level*4,z])

def room(b,name,x,z,level=0):b['rooms'].append({'name':name,'point':[x,level*4,z],'level':level})
def line(b,axis,fixed,start,end,doors=(),level=0,style='wood'):
 for v in range(start+1,end,2):
  id='doorway_wood' if v in doors else 'wall_'+style+'_solid'
  p(b,id,v if axis=='x' else fixed,fixed if axis=='x' else v,r=0 if axis=='x' else 90,level=level,group='Walls')

def shell(b,front_door=None,mask=None):
 w,d=b['width'],b['depth'];door=front_door if front_door is not None else b['entry'][0];b['entry'][0]=door
 for level in range(b['levels']):
  for x in range(1,w,2):
   for z in range(1,d,2):
    if mask and not mask(x,z):continue
    if level==b['levels']-1:b['roof_tiles'].append([x,z])
    if level==1 and 6<x<10 and 4<z<14:continue
    b['floors'].append({'x':x,'z':z,'level':level,'id':b['default_floor']})
  for x in range(1,w,2):
   for z in [-.125,d+.125]:
    id='doorway_wood' if level==0 and x==door and z<0 else 'wall_'+b['wall']+('_window' if x%4==1 else '_solid')
    p(b,id,x,z,level=level,group='Walls')
  for z in range(1,d,2):
   for x in [-.125,w+.125]:p(b,'wall_'+b['wall']+('_window' if z%4==1 else '_solid'),x,z,r=90,level=level,group='Walls')
 p(b,'entry_mat',door,.8,y=.005)
 for x in range(1,w,2):p(b,'sidewalk',x,-1,y=-2,group='Exterior')
 p(b,'coat_rack',door+2,1.5)

def zone(b,x0,z0,x1,z1,material,level=0):
 for f in b['floors']:
  if f['level']==level and x0<f['x']<x1 and z0<f['z']<z1:f['id']=material

def kitchen(b,x,z,level=0):
 for id,dx in [('fridge',0),('sink_counter',2),('stove',4)]:p(b,id,x+dx,z,level=level)
 p(b,'wall_cabinet',x+2,z,y=1.3,level=level,group='Details')

def bedroom(b,x,z,level=0):
 p(b,'bed',x,z,level=level);p(b,'nightstand',x+1.6,z+.9,level=level);p(b,'wardrobe',x+3.2,z+1,level=level)

def bath(b,x,z,level=0,tub=False):
 p(b,'toilet',x,z,level=level);p(b,'bath_sink',x+2,z,level=level)
 p(b,'bath_mirror',x+2,z+.45,y=1.2,level=level,group='Details')
 if tub:p(b,'bathtub',x+4,z-.8,level=level)

def lounge(b,x,z,level=0):
 p(b,'sofa',x,z,level=level);p(b,'rug',x,z-2,y=.004,level=level);p(b,'coffee_table',x,z-2,y=.023,level=level);p(b,'dishes',x,z-2,y=.9,level=level);p(b,'tv_console',x+3.3,z-1,r=-90,level=level)

def dining(b,x,z,level=0):
 p(b,'table',x,z,level=level);p(b,'dishes',x,z,y=1.065,level=level)
 for dz,r in [(-1.35,0),(1.35,180)]:p(b,'chair',x,z+dz,r=r,level=level)

def sign(b,text,x,z,y=2.3):b['signs'].append({'text':text,'position':[x,y,z]})

b=building('cedar_cottage','Cedar Cottage',12,10,'wood',pitched=True);shell(b,5)
line(b,'x',6,0,12,[3,9]);line(b,'z',6,6,10);line(b,'z',8,0,6,[5]);line(b,'x',4,8,12,[9])
zone(b,8,0,12,4,'floor_bath_tile');zone(b,6,6,12,10,'floor_carpet')
lounge(b,3,3.4);kitchen(b,.9,9.1);bedroom(b,7.5,8);bath(b,9,1.1)
p(b,'bookcase',.8,2,r=90);p(b,'laundry_basket',11.2,6.8)
for name,x,z in [('Living room',5,2.5),('Kitchen',3,7.2),('Bedroom',9,6.8),('Bathroom',10,2.4)]:room(b,name,x,z)
p(b,'bench',1,-2);p(b,'weeds',11,-1.7);sign(b,'CEDAR  /  12',5,-.34,2.35)

b=building('maple_family_house','Maple Family House',16,14,'plaster',pitched=True);shell(b,7)
line(b,'z',10,0,14,[3,9,13]);line(b,'x',6,10,16);line(b,'x',10,10,16);line(b,'x',10,0,10,[7])
zone(b,10,0,16,6,'floor_carpet');zone(b,10,6,16,10,'floor_bath_tile');zone(b,10,10,16,14,'floor_carpet')
lounge(b,3.5,5.3);dining(b,7,7);kitchen(b,1.2,13.1);p(b,'bed',13,3);p(b,'nightstand',14.6,3.9);p(b,'wardrobe',11.2,5.2);p(b,'bed',13,12);p(b,'nightstand',14.6,12.9);p(b,'wardrobe',11.2,10.7);bath(b,11,7.1);p(b,'bathtub',15,8)
p(b,'desk',3,8.8);p(b,'desk_items',3,8.8,y=1.065);p(b,'bookcase',.8,7,r=90);p(b,'laundry_basket',13,9.3)
for x in range(3,12,2):
 p(b,'floor_wood',x,-3,y=-2,group='Exterior');p(b,'shop_awning',x,-2.7,y=2.15,group='Exterior')
for x in [2,12]:p(b,'pillar',x,-3.7,group='Exterior')
p(b,'bench',4,-3,r=180);p(b,'garden_tools',14.8,-.5)
for name,x,z in [('Lounge',7,2),('Dining room',7,5),('Kitchen',7,11.5),('Main bedroom',11.2,2),('Bathroom',12,9),('Second bedroom',11.2,12.5)]:room(b,name,x,z)
sign(b,'MAPLE HOUSE',7,-.34,2.35)

b=building('ash_walkup_apartments','Ash Walk-up Apartments',16,16,'brick_red',levels=2);shell(b,7)
for level in range(2):
 entry_z=3 if level==0 else 15
 line(b,'z',6,0,16,[entry_z],level);line(b,'z',10,0,16,[entry_z],level)
 for start in [0,10]:
  cuts=[8,12] if level==0 else [4,8]
  for z in cuts:line(b,'x',z,start,start+6,[start+3],level)
  living_z=4 if level==0 else 12;bed_z=10 if level==0 else 2;bath_z=14 if level==0 else 6
  p(b,'sofa',start+2,living_z+1,level=level);p(b,'coffee_table',start+2,living_z-1,level=level)
  p(b,'sink_counter',start+4.8,6 if level==0 else 11,r=-90,level=level);p(b,'fridge',start+4.8,1 if level==0 else 8.9,r=-90,level=level)
  bedroom(b,start+1.5,bed_z,level);p(b,'toilet',start+1,bath_z+.6,level=level);p(b,'bath_sink',start+5,bath_z+.6,level=level)
  zone(b,start,bath_z-2,start+6,bath_z+2,'floor_bath_tile',level)
  for label,z in [('Living',living_z),('Bedroom',bed_z),('Bathroom',bath_z)]:room(b,f'Flat {level*2+(1 if start==0 else 2)} - {label}',start+3,z-1,level)
 p(b,'mailboxes',6.55,1.5,r=90,level=level)
p(b,'stairs',8,8,group='Stairs');p(b,'stairs',8,12,y=2,group='Stairs')
room(b,'Upper landing',8,15,1);room(b,'Entry hall',8,2)
sign(b,'ASH APARTMENTS',7,-.35,2.7);p(b,'sign_apartments',12,-.35,y=2.3,group='Exterior')

b=building('courtyard_apartments','Courtyard Apartments',20,16,'brick',floor='floor_wood')
mask=lambda x,z: x<6 or x>14 or z>10
shell(b,9,mask)
b['pieces']=[q for q in b['pieces'] if not (q['group']=='Walls' and q['position'][2]<0 and 6<q['position'][0]<14)]
for fixed in [6,14]:line(b,'z',fixed,0,16,[3,11])
line(b,'x',10,6,14,[9]);line(b,'x',8,0,6);line(b,'x',8,14,20)
for start in [0,14]:
 for row in [0,8]:
  mirror=lambda x: start+x if start==0 else start+6-x
  p(b,'bed',mirror(1.25),row+3.7)
  p(b,'sink_counter',mirror(1.2),row+.8);p(b,'stove',mirror(3.2),row+.8);p(b,'fridge',mirror(5),row+.9)
  p(b,'table',mirror(4.4),row+3.7);p(b,'dishes',mirror(4.4),row+3.7,y=1.065)
  low,high=(start+2,start+6) if start==0 else (start,start+4)
  line(b,'x',row+6,low,high,[mirror(5)]);line(b,'z',mirror(2),row+6,row+8)
  p(b,'toilet',mirror(3),row+7.1);p(b,'bath_sink',mirror(5),row+7.4)
  zone(b,low,row+6,high,row+8,'floor_bath_tile')
  number=1+row//8+(2 if start else 0)
  room(b,f'Studio {number}',start+3,row+3);room(b,f'Studio {number} washroom',mirror(4),row+6.6)
for x in [7,9,11,13]:
 for z in [1,3,5,7,9]:p(b,'sidewalk',x,z,y=-2,group='Exterior')
p(b,'dry_fountain',10,5,group='Exterior');p(b,'bench',7.3,7,r=90,group='Exterior');p(b,'bench',12.7,7,r=-90,group='Exterior')
p(b,'mailboxes',13.3,13,r=90);p(b,'locker',7.2,14.8);p(b,'locker',8.5,14.8);p(b,'water_dispenser',12.5,14.8);p(b,'laundry_basket',11,14.8)
room(b,'Shared laundry',10,12);b['entry']=[9,0,-.125];sign(b,'COURTYARD HOMES',10,9.7,2.4)

b=building('corner_grocery','Corner Grocery',14,12,'brick',floor='floor_shop_tile');shell(b,5)
line(b,'x',8,0,14,[3,11],style='plaster');line(b,'z',10,8,12)
zone(b,0,8,10,12,'floor_concrete_worn');zone(b,10,10,14,12,'floor_bath_tile')
for x in [3,7]:
 for z in [3.3,6]:p(b,'gondola_stocked',x,z)
for z in [2,5]:p(b,'display_fridge',12.8,z,r=-90)
p(b,'checkout_counter',1.7,1.2);p(b,'register',1.7,1.2,y=1.21);p(b,'produce_bin',9.7,1.4)
p(b,'storage_rack',2.5,11);p(b,'open_crate',5.5,10);p(b,'cardboard_box',7,10);bath(b,11,11.1)
for x in [1,3,5,7,9,11,13]:p(b,'shop_awning',x,-.85,y=2.1,group='Exterior')
sign(b,'CORNER GROCERY',7,-.95,2.55);p(b,'dumpster',15.8,9,group='Exterior')
for name,x,z in [('Shop aisles',5,4.5),('Cold goods',11,4.5),('Stockroom',7,9),('Staff hall',11,9),('Washroom',12,10.5)]:room(b,name,x,z)

b=building('morrow_hospital','Morrow Community Hospital',20,18,'plaster',floor='floor_clinic_tile');shell(b,9)
for x in [8,12]:line(b,'z',x,0,18,[3,9,15],style='plaster')
for start in [0,12]:
 for z in [6,12]:line(b,'x',z,start,start+8,style='plaster')
line(b,'z',4,12,18,[15],style='plaster')
for q in b['pieces']:
 if q['group']=='Walls' and q['position']==[17,0,-.125]:q['id']='doorway_wood'
p(b,'reception_desk',3,4.5);p(b,'desk_items',3,4.5,y=1.565);p(b,'filing_cabinet',1,5.1)
for x in [1,3,5]:p(b,'waiting_chair',x,1.5,r=180)
p(b,'water_dispenser',6.8,5.1)
for z in [8,10]:p(b,'medicine_cabinet',1,z,r=90)
for x in [3,5,7]:p(b,'medicine_cabinet',x,11.2)
p(b,'checkout_counter',4,7.2);p(b,'register',4,7.2,y=1.21)
p(b,'break_table',6,17);p(b,'chair',6,15.5);p(b,'dishes',6,17,y=1.065)
for x in [5,6.5]:p(b,'locker',x,13)
bath(b,1,16.8);p(b,'bathtub',1,14);zone(b,0,12,4,18,'floor_bath_tile')
p(b,'exam_bed',15,3.4);p(b,'medical_trolley',19,3.4);p(b,'iv_stand',13.5,4.7);p(b,'medicine_cabinet',19,4.9,r=-90)
for x in [14.8,18]:p(b,'exam_bed',x,9)
p(b,'medical_trolley',16.5,11);p(b,'privacy_screen',16.5,9,r=90);p(b,'iv_stand',13,10.8)
for x in [14.5,18]:p(b,'bed',x,15)
p(b,'nightstand',16.1,16);p(b,'iv_stand',19.5,15.5);p(b,'bookcase',13.1,17.3)
p(b,'bench',10,17);p(b,'wall_clock',10,17.7,y=1.3,group='Details')
for name,x,z in [('Reception and waiting',6.5,3),('Pharmacy',6.5,9),('Staff break room',6,14.5),('Accessible washroom',2.8,14.5),('Emergency and triage',17,2),('Treatment bay A',13,8.5),('Treatment bay B',18,6.8),('Patient ward',13,14),('Ward bedside route',17,12.7)]:room(b,name,x,z)
for x in [15,17,19]:p(b,'shop_awning',x,-.8,y=2.25,group='Exterior')
p(b,'ambulance',23,-3,group='Exterior');p(b,'clinic_sign',1,-.35,y=1.1,group='Exterior')
sign(b,'MORROW HOSPITAL',8,-.4,2.45);sign(b,'EMERGENCY',17,-1,2.7)
for x in [3,7]:p(b,'bench',x,-1.7,group='Exterior')

b=building('ash_street_diner','Ash Street Diner',16,10,'corrugated',floor='floor_shop_tile');shell(b,7)
line(b,'x',6,0,16,[13],style='plaster')
for x in [6,10,13.5]:
 dining(b,x,2.8)
for z in [2,4]:
 p(b,'kitchen_counter',1,z,r=90);p(b,'chair',2.4,z,r=90)
kitchen(b,1.2,9);p(b,'workbench',8,9);p(b,'dishes',8,9,y=1.065);p(b,'storage_rack',11,9);p(b,'trash_bag',15,8.8)
p(b,'register',1,2,y=1.13);p(b,'wall_clock',8,5.7,y=1.35,group='Details')
for x in range(1,16,2):p(b,'shop_awning',x,-.8,y=2.15,group='Exterior')
sign(b,'ASH STREET DINER',8,-.95,2.5);p(b,'signpost',15,-1.8,group='Exterior');p(b,'dumpster',17.5,8,group='Exterior')
room(b,'Dining area',12,3);room(b,'Counter service',11,5);room(b,'Kitchen',13,7.5)

b=building('lantern_restaurant','The Lantern Restaurant',16,14,'brick_red',floor='floor_wood');shell(b,7)
line(b,'x',8,0,16,[11],style='plaster');line(b,'z',4,8,14,[9]);line(b,'x',10,0,4,[1])
for x in [3,7,11]:
 for z in [2.5,6]:
  if x!=7 or z!=2.5:dining(b,x,z)
p(b,'reception_desk',14.4,2,r=-90);p(b,'shelf',14.9,6,r=-90)
kitchen(b,5.2,13);p(b,'workbench',12,13);p(b,'dishes',12,13,y=1.065);p(b,'storage_rack',14.8,10.5,r=-90)
bath(b,1,13.1);p(b,'coat_rack',.7,8.5);zone(b,0,10,4,14,'floor_bath_tile');zone(b,4,8,16,14,'floor_tile')
for x in [1,3,5]:
 for z in [-3,-5]:p(b,'floor_shop_tile',x,z,y=-2,group='Exterior')
dining(b,3,-4);p(b,'fence',0,-4,r=90,group='Exterior');p(b,'fence',6,-4,r=90,group='Exterior')
sign(b,'THE LANTERN',8,-.4,2.4);p(b,'street_lamp',6.5,-4,group='Exterior')
for name,x,z in [('Dining room',13,4.5),('Kitchen',10,10),('Cloakroom',2.8,9),('Washroom',2,11)]:room(b,name,x,z)

b=building('fuel_stop','Fuel Stop Gas Station',14,10,'corrugated',floor='floor_shop_tile');shell(b,7)
line(b,'x',6,0,14,[3,11],style='plaster');line(b,'z',10,6,10)
for x in [2,6,10]:p(b,'gondola_stocked',x,3)
p(b,'checkout_counter',1.7,1.1);p(b,'register',1.7,1.1,y=1.21);p(b,'display_fridge',12.8,3,r=-90)
p(b,'storage_rack',3,9);p(b,'crate',7,8.7);bath(b,11,8.8);zone(b,10,6,14,10,'floor_bath_tile')
for x in range(1,16,2):
 for z in [-3,-5,-7,-9,-11]:p(b,'road_asphalt',x,z,y=-2,group='Exterior')
p(b,'gas_canopy',5,-7,group='Exterior');p(b,'gas_pump',3,-7,group='Exterior');p(b,'gas_pump',7,-7,group='Exterior')
p(b,'gas_pump',11,-7,group='Exterior');p(b,'signpost',14,-10,group='Exterior');p(b,'barrel',15.5,7,group='Exterior');p(b,'dumpster',15.5,9,group='Exterior')
for x in [1.7,8.3,11]:p(b,'bollard',x,-5.4,group='Exterior')
sign(b,'FUEL STOP',7,-.4,2.45);p(b,'sign_gas',5,-9.1,y=2.5,group='Exterior')
for name,x,z in [('Convenience store',8,4.5),('Stockroom',6,7.5),('Washroom',12,7.5)]:room(b,name,x,z)

b=building('oakwood_school','Oakwood School',20,16,'brick',floor='floor_tile');shell(b,9)
for x in [8,12]:line(b,'z',x,0,16,[3,9,13],style='plaster')
for start in [0,12]:
 for z in [6,12]:line(b,'x',z,start,start+8,style='plaster')
 for row in [0,6]:
  for x in [start+2,start+5]:
   for z in [row+1.5,row+4.2]:
    p(b,'desk',x,z);p(b,'chair',x,z-.9);p(b,'desk_items',x,z,y=1.065)
  p(b,'desk',start+4,row+5.35);p(b,'bookcase',start+.7,row+4.8,r=90);p(b,'sign_panel',start+4,row+5.8,y=1.25,group='Details')
  room(b,('Classroom A' if row==0 else 'Classroom B')+(' East' if start else ' West'),start+7,row+3.5)
line(b,'z',4,12,16,[13],style='plaster');bath(b,1,15.0);zone(b,0,12,4,16,'floor_bath_tile')
p(b,'desk',6.5,15);p(b,'desk_items',6.5,15,y=1.065);p(b,'chair',5.5,13.2);p(b,'filing_cabinet',4.7,15.2)
for x in [14,16,18]:p(b,'bookcase',x,15.5)
p(b,'break_table',16,13.5);p(b,'chair',14.4,13.5,r=90);p(b,'chair',17.6,13.5,r=-90)
for z in [4,6,8,10]:p(b,'locker',8.8,z,r=90)
p(b,'water_dispenser',11.3,11);p(b,'wall_clock',10,15.75,y=1.3,group='Details')
for name,x,z in [('Staff office',7,14),('Washroom',2,13.5),('Library',13.2,13.5),('School hallway',10,8)]:room(b,name,x,z)
for x in [3,17]:p(b,'bench',x,-1.7,group='Exterior')
sign(b,'OAKWOOD SCHOOL',10,-.4,2.45);p(b,'fence',-2,3,r=90,group='Exterior');p(b,'fence',-2,5,r=90,group='Exterior')

b=building('district_police_station','District Police Station',18,16,'brick_red',floor='floor_concrete');shell(b,7)
line(b,'z',6,0,16,[3,9,13],style='plaster');line(b,'z',10,0,16,[3,9],style='plaster')
for z in [6,12]:line(b,'x',z,0,6,style='plaster')
line(b,'x',8,10,18,[13],style='plaster');line(b,'x',10,10,18,[11,15],style='brick');line(b,'z',14,10,16,style='brick')
p(b,'reception_desk',3,4.5);p(b,'desk_items',3,4.5,y=1.565)
for x in [1,3]:p(b,'waiting_chair',x,1.5,r=180)
dining(b,3,9);p(b,'filing_cabinet',1,10.8);p(b,'wall_clock',3,11.7,y=1.3,group='Details')
for x in [1.5,4.5]:p(b,'parts_shelf',x,15.1)
p(b,'open_crate',2,13.3);p(b,'cardboard_box',3.5,13.3)
for x in [13,16]:dining(b,x,3)
p(b,'sign_panel',14,7.8,y=1.2,group='Details');p(b,'desk',16,6.5);p(b,'desk_items',16,6.5,y=1.065)
for x in [12.8,16.8]:
 p(b,'bed',x,13.5);p(b,'toilet',x-1.8,15.1)
for z in [5,7]:p(b,'locker',9.3,z,r=-90)
for name,x,z in [('Public reception',4,2),('Interview room',4.7,9),('Evidence storage',4.5,13),('Briefing room',11.5,5),('Holding corridor',13,9),('Holding cell A',11.1,12),('Holding cell B',15.1,12)]:room(b,name,x,z)
sign(b,'DISTRICT POLICE',8,-.4,2.5)
for x in [3,11,15]:p(b,'bollard',x,-1.5,group='Exterior')
p(b,'concrete_barrier',-2,-3,group='Exterior');p(b,'street_lamp',17,-2,group='Exterior')

for b in all_buildings:
 if b['id']=='cedar_cottage':
  for q in b['pieces']:
   if q['id']=='coat_rack':q['position']=[11,0,5]
 if b['id']=='maple_family_house':
  for q in b['pieces']:
   if q['id']=='tv_console':q['position']=[.8,0,4];q['rotation']=90
 if b['id']=='courtyard_apartments':
  for q in b['pieces']:
   if q['id']=='doorway_wood' and q['position'][0]==5 and q['position'][2] in [6,14]:q['rotation']=180
 if b['id']=='district_police_station':
  for q in b['pieces']:
   if q['id']=='doorway_wood' and q['position'][2]==10:q['rotation']=180
 if b['id']=='cedar_cottage':
  for q in b['pieces']:
   if q['id']=='doorway_wood' and q['position']==[9,0,6]:q['rotation']=180
 if b['pitched']:
  for sign_entry in b['signs']:sign_entry['position'][2]=-.46
 if b['id']=='lantern_restaurant':b['pieces']=[q for q in b['pieces'] if not (q['id']=='chair' and q['position'][0]==11 and q['position'][2]==7.35)]
 if b['id']=='ash_walkup_apartments':
  b['pieces']=[q for q in b['pieces'] if q['id']!='nightstand']
  for x in range(1,16,2):
   for z in [-.125,16.125]:p(b,'wall_brick_red_solid',x,z,y=2,group='Walls')
  for z in range(1,16,2):
   for x in [-.125,16.125]:p(b,'wall_brick_red_solid',x,z,y=2,r=90,group='Walls')
 b['description']='Independent furnished building assembled from the existing 32-pixel city modules, with mesh collisions, hinged doors, and automatic interior cutaway.'
(ROOT/'output/buildings/building_specs.json').write_text(json.dumps({'buildings':all_buildings},indent=2))
print('Prepared',len(all_buildings),'building layouts;',sum(len(b['pieces'])+len(b['floors']) for b in all_buildings),'modular placements')
