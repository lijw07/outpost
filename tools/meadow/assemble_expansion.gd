extends SceneTree
const BASE="res://assets/models/meadow_expansion/scenes/"
const HELPER=preload("res://scripts/parks/park_district_layout.gd")
const BLOCKS=preload("res://scripts/world/block_library.gd")
const BACKUP="res://output/meadow_scene_integration/backup/"
var district:Node3D
var expansion:Node3D
var ground:GridMap
var serial:=0
var placed:={}
var helper=HELPER.new()
func _initialize():call_deferred("run")
func own(n,r):
 for c in n.get_children():
  c.owner=r
  if c.scene_file_path.is_empty():own(c,r)
func node(label,parent):
 var n=Node3D.new();n.name=label;parent.add_child(n);return n
func asset(id,p,parent,turn=0.0):
 var path=BASE+id+".tscn"
 if id.begins_with("city:"):path="res://assets/models/city/scenes/"+id.trim_prefix("city:")+".tscn"
 if id.begins_with("street:"):path="res://assets/models/city/street_mobility/scenes/"+id.trim_prefix("street:")+".tscn"
 if id.begins_with("tree:"):path="res://assets/models/trees/scenes/"+id.trim_prefix("tree:")+".tscn"
 if id.begins_with("plant:"):path="res://assets/models/plants/scenes/"+id.trim_prefix("plant:")+".tscn"
 var n=load(path).instantiate();n.name=id.replace(":","_")+"_%04d"%serial;serial+=1;n.position=p;n.rotation.y=turn;parent.add_child(n)
 placed[id]=placed.get(id,0)+1
 return n
func save(n,path):
 own(n,n);var packed=PackedScene.new();assert(packed.pack(n)==OK);assert(ResourceSaver.save(packed,path)==OK)
func grid_id(id):
 for i in ground.mesh_library.get_item_list():
  if ground.mesh_library.get_item_name(i).split(":")[0]==id:return i
 return -1
func tile_rect(rect,id):
 var item=grid_id(id);assert(item>=0,id)
 for x in range(floori(rect.position.x/2),ceili(rect.end.x/2)):
  for z in range(floori(rect.position.y/2),ceili(rect.end.y/2)):ground.set_cell_item(Vector3i(x,0,z),item)
func clear_region(rect):
 for n in district.get_children():
  if n is GridMap or n==expansion or n.get_meta("district_scenery",false) or n.name in ["MeadowCommonsPark","CoastalQuarter"]:continue
  if n.name=="MeadowUnderstory":
   for c in n.get_children():
    if c is MultiMeshInstance3D:
     var keep:Array[Transform3D]=[]
     for t in c.placements:
      if not rect.grow(1.2).has_point(Vector2(t.origin.x,t.origin.z)):keep.append(t)
     var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=c.multimesh.mesh;mm.instance_count=keep.size();c.placements=keep;c.multimesh=mm
     for i in keep.size():c.multimesh.set_instance_transform(i,keep[i])
    elif c is StaticBody3D:
     for shape in c.get_children():
      if rect.grow(1.2).has_point(Vector2(shape.position.x,shape.position.z)):shape.free()
  elif n.name=="MeadowStreetscape":
   for c in n.get_children():
    if c is Node3D and helper.bounds(c).intersects(rect):c.free()
  elif n is Node3D and helper.bounds(n).intersects(rect):n.free()
 var coast=district.get_node("CoastalQuarter/GardensAndStreetFurniture")
 for c in coast.get_children():
  if c is Node3D and helper.bounds(c).intersects(rect):c.free()
func mall():
 var b=node("MeadowMall",expansion);b.position=Vector3(-44,0,-45);b.rotation.y=PI;b.set_meta("district_scenery",true)
 var floor0=node("GroundFloor",b);var floor1=node("UpperFloor",b);var roof=node("Roof",b)
 for x in range(-23,24,2):
  for z in range(-8,9,2):
   asset("mall_roof_tile",Vector3(x,-.1875,z),floor0)
   if not (abs(x)<=3 and abs(z)<=3) and not (x>=15 and x<=19 and z>=2 and z<=4):asset("mall_roof_tile",Vector3(x,1.8125,z),floor1)
   if abs(x)<=5 and abs(z)<=3:asset("atrium_glass_panel",Vector3(x,4,z),roof)
   else:asset("mall_roof_tile",Vector3(x,4,z),roof)
 for x in range(-23,24,2):
  if abs(x)>1:
   asset("mall_storefront_glass",Vector3(x,0,-9),floor0)
   asset("mall_upper_window",Vector3(x,2,-9),floor1)
   asset("mall_cornice_straight",Vector3(x,3.56,-9.12),roof)
   if abs(x)>5:asset("city:shop_awning",Vector3(x,1.65,-9.2),floor0)
  asset("mall_wall_brick",Vector3(x,0,9),floor0,PI);asset("mall_upper_window",Vector3(x,2,9),floor1,PI)
 for x in [-24,24]:
  for z in range(-8,9,2):asset("mall_wall_brick",Vector3(x,0,z),floor0,PI/2);asset("mall_upper_window",Vector3(x,2,z),floor1,PI/2)
 for x in range(-24,25,4):
  if abs(x)<3:continue
  for y in [0,2]:asset("mall_pilaster",Vector3(x,y,-9.3),b)
 for pair in [["left",-1],["right",1]]:
  asset("mall_arch_jamb_"+pair[0],Vector3(pair[1],0,-9.4),b)
  asset("mall_arch_"+pair[0],Vector3(pair[1],2,-9.4),b)
  asset("arch_glass_"+pair[0],Vector3(pair[1],2,-9.3),b)
  asset("mall_double_glass_door_open",Vector3(pair[1],0,-9.22),floor0)
 asset("sign_mall",Vector3(0,1.3,-9.65),b)
 for x in [-19,-17,-15]:asset("cinema_marquee",Vector3(x,1.5,-9.55),b)
 asset("sign_cinema",Vector3(-17,2.05,-10.05),b)
 for x in [-21,-13]:asset("cinema_poster_case",Vector3(x,.05,-9.3),b)
 for x in [-19,-11,11,19]:asset("mall_hvac",Vector3(x,4.1875,3),roof)
 for x in [-16,-8,8,16]:asset("shop_display_shelf",Vector3(x,0,-6),floor0);asset("shop_clothing_rack",Vector3(x,0,5),floor0)
 asset("dock_stairs_tile",Vector3(17,0,3),floor0,PI)
 for x in [-4,4]:
  for z in range(-2,3,2):asset("dock_wood_railing",Vector3(x,2,z),floor1,PI/2)
 save(b,"res://scenes/meadow/meadow_mall.tscn")
 return b
func recipe(name,at,parent,turn=PI,skip_ground=true):
 var b=node(name,parent);b.position=at;b.rotation.y=turn
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://output/meadow_expansion_kit_v1/review/"+name+"_layout.json"))
 for row_index in data.placements.size():
  var row=data.placements[row_index]
  if skip_ground and row.id=="sidewalk_block":continue
  var id=row.id
  if row.source=="city":id="city:"+id
  elif row.source=="city/street_mobility":id="street:"+id
  if id=="mall_double_glass_door":id="mall_double_glass_door_open"
  var position3=Vector3(row.at[0],row.at[1],row.at[2])/16.0
  if name=="retail_lane_assembly" and row_index>=78 and row_index<246:position3.x+=floorf(float(row_index-78)/56)-1
  asset(id,position3,b,deg_to_rad(row.yaw))
 return b
func visitor(p,q,parent,outfit):
 var n=node("Visitor_%03d"%serial,parent);serial+=1;n.set_script(preload("res://scripts/meadow/district_visitor.gd"));n.route=PackedVector3Array([p,q]);n.position=p;n.outfit=outfit
 var s=Sprite3D.new();s.name="Sprite";s.texture=load("res://assets/models/meadow_expansion/textures/"+outfit+"_front_0.png");s.pixel_size=1.0/16;s.position.y=1;s.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;s.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;s.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD;n.add_child(s);n._ready()
func plaza():
 var p=node("ShoppingPlaza",expansion)
 for x in [-64,-54,-34,-24]:
  for z in [-30,-21]:
   asset("street:flower_planter",Vector3(x,0,z),p);asset("tree:meadow_oak_young",Vector3(x+2,0,z),p)
 for x in [-61,-27]:
  for z in [-29,-19,-7]:asset("street:street_light",Vector3(x,0,z),p)
 for x in [-58,-30]:
  for z in [-27,-22]:
   asset("cafe_round_table",Vector3(x,0,z),p);asset("umbrella_sage",Vector3(x,.9375,z),p)
   asset("cafe_chair",Vector3(x-1,0,z),p,PI/2);asset("cafe_chair",Vector3(x+1,0,z),p,-PI/2)
 for x in [-46,-44,-42]:
  for z in [-25,-23,-21]:
   cell_replace(x,z,"plaza_inlay_block",p)
 asset("fountain_water_basin",Vector3(-44,0,-23),p);asset("fountain_spout",Vector3(-44,.25,-23),p)
 for x in [-49,-39]:
  for z in [-26,-24,-22,-20]:asset("hedge_straight",Vector3(x,0,z),p,PI/2)
 asset("mall_directory",Vector3(-41,0,-14),p,PI);asset("bicycle_rack",Vector3(-65,0,-10),p)
 for x in [-65,-64]:asset("bicycle",Vector3(x,0,-11),p,PI/2)
 for x in [-52,-36]:
  for z in [-16,-9]:asset("flower_pot_terracotta",Vector3(x,0,z),p)
 for x in [-36,-24]:
  for z in [-10,0]:
   for dx in [-1,1]:
    for dz in [-1,1]:cell_replace(x+dx,z+dz,"plaza_inlay_block",p)
   asset("street:flower_planter",Vector3(x,0,z),p);asset("tree:meadow_oak_young",Vector3(x,0,z),p)
   asset("city:bench",Vector3(x,0,z+2.6),p)
 var shops=recipe("retail_lane_assembly",Vector3(-53,0,-8),expansion,PI)
 remove_floor_ground(shops,ground)
 save(shops,"res://scenes/meadow/retail_lane.tscn")
 for i in 12:
  var x=-65+i*3.7;visitor(Vector3(x,0,-33),Vector3(x+2,0,-33),p,["civilian_sage","civilian_cream","civilian_ochre","civilian_rust"][i%4])
 for x in [-40,-38]:visitor(Vector3(x,0,-17),Vector3(x,0,-3),p,"civilian_sage")
func remove_floor_ground(building,grid):
 for c in building.get_children():
  if str(c.name).begins_with("mall_roof_tile") and absf(c.global_position.y+.1875)<.01:
   grid.set_cell_item(Vector3i(floori(c.global_position.x/2),0,floori(c.global_position.z/2)),-1)
func cell_replace(x,z,id,p):
 var cell=Vector3i(floori(x/2),0,floori(z/2));ground.set_cell_item(cell,-1);asset(id,Vector3(cell.x*2+1,-2,cell.z*2+1),p)
func parking():
 var p=node("MallParking",expansion)
 for z in range(-45,2,5):
  var c=Vector3i(-39,0,floori(float(z)/2));ground.set_cell_item(c,-1)
  asset("street:parking_bay_block",Vector3(-77,-2,c.z*2+1),p,PI/2)
  if z%3:asset("city:sedan",Vector3(-77,0,z),p,PI/2)
 for z in [-49,-33,-17,1]:asset("street:flower_planter",Vector3(-73,0,z),p);asset("street:street_light",Vector3(-72,0,z),p)
 asset("street:bus_stop_shelter",Vector3(-73,0,16),p,PI)
 asset("street:bus_stop_sign",Vector3(-70,0,16),p,PI)
 asset("city:bus",Vector3(-73,0,23),p,PI/2)
func coast_details():
 var coast=district.get_node("CoastalQuarter");var old=coast.get_node("GardensAndStreetFurniture")
 extend_shore(coast)
 var beach_points=[Vector2(-28,72),Vector2(-10,75),Vector2(12,71),Vector2(32,69)]
 for c in old.get_children():
  var id=c.get_meta("asset_id","")
  for p in beach_points:
   if Vector2(c.position.x,c.position.z).distance_to(p)<3 and id in ["table","chair","shop_awning","pillar"]:c.free();break
 var p=node("ApprovedWaterfrontDetails",coast)
 for i in beach_points.size():
  var at=beach_points[i]
  asset("umbrella_sage" if i%2==0 else "umbrella_ochre",Vector3(at.x,0,at.y),p)
  asset("beach_lounger",Vector3(at.x+1.3,0,at.y),p,PI)
  asset("beach_towel",Vector3(at.x-1.2,0,at.y+.3),p)
  asset("beach_sunhat",Vector3(at.x+2.5,0,at.y+1.7),p)
  asset("sandcastle",Vector3(at.x-2.2,0,at.y+2),p);asset("beach_bucket",Vector3(at.x-2.9,0,at.y+2.4),p)
 for x in range(-42,44,3):asset("dune_grass",Vector3(x,0,64+sin(x*.3)),p)
 var pier=coast.get_node("TimberPier");var lib=pier.mesh_library.duplicate(true)
 var deck=load(BASE+"dock_deck_tile.tscn").instantiate();var mesh=deck.get_node("Visual").mesh
 for i in lib.get_item_list():lib.set_item_mesh(i,mesh);lib.set_item_shapes(i,[mesh.create_trimesh_shape(),Transform3D.IDENTITY])
 pier.mesh_library=lib;deck.free()
 for c in old.get_children():
  if c.get_meta("asset_id","")=="fence" and c.position.z>=62:
   asset("dock_wood_railing",c.position,p,c.rotation.y);c.free()
 for z in range(64,103,4):
  for x in [60.2,65.8]:asset("dock_piling",Vector3(x,-1.9,z),p)
 for x in range(49,78,4):asset("dock_piling",Vector3(x,-1.9,89.6),p);asset("mooring_cleat",Vector3(x,0,89.4),p)
 for at in [Vector3(59.8,.4,82),Vector3(66.2,.4,94)]:asset("life_ring",at,p,PI/2)
 asset("mooring_rope_coil",Vector3(67,0,88),p);asset("sign_dock",Vector3(66,1.3,60),p,PI)
 var hut=coast.get_node("HarborCottage")
 for part in hut.find_children("*","Node3D",true,false):
  if part.get_meta("terrain_block",false) and absf(part.global_position.y+2)<.01:pier.set_cell_item(Vector3i(floori(part.global_position.x/2),0,floori(part.global_position.z/2)),3)
 hut.free()
 var house=recipe("boathouse_assembly",Vector3(70,0,80),p,PI);house.name="BaitBoathouse";remove_floor_ground(house,pier)
 var r=recipe("rowboat_assembly",Vector3(54,-.1,94),p,PI);r.name="MooredRowboat"
 var f=recipe("fishing_boat_assembly",Vector3(76,-.1,95),p,PI);f.name="MooredFishingBoat"
 asset("fisher",Vector3(65,0,100),p);asset("fishing_rod",Vector3(65.5,0,100),p)
 for v in coast.get_node("PromenadeVisitors").get_children():
  var path=v.route;var pos=v.position;var speed=v.speed;var index=v.get_index();var parent=v.get_parent();v.free()
  visitor(path[0],path[1],parent,["civilian_sage","civilian_ochre","civilian_cream","civilian_rust"][index%4]);var n=parent.get_child(parent.get_child_count()-1);n.position=pos;n.speed=speed
 own(coast,coast);save(coast,"res://scenes/coast/meadow_waterfront.tscn")
func extend_shore(coast):
 var terrain=coast.get_node("CoastalTerrain")
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for x in range(-47,46):
  var end=roundi(floorf((81.0-.16*(x*2+1)+3*sin((x*2+1)*.08))/2.0))
  if x< -24:
   for z in range(28,end):
    ground.set_cell_item(Vector3i(x,0,z),-1)
    var dune_end=32+roundi(sin(x*.27)*1.4)
    terrain.set_cell_item(Vector3i(x,0,z),2 if z<30 else (0 if z<dune_end else 1))
  var corners=[Vector3(x*2,-.16,end*2),Vector3(x*2+2,-.16,end*2),Vector3(x*2+2,-.16,220),Vector3(x*2,-.16,220)]
  for i in [0,2,1,0,3,2]:st.set_normal(Vector3.UP);st.add_vertex(corners[i])
 coast.get_node("MeadowBay").mesh=st.commit()
 var p=node("WestPromenade",coast)
 for x in range(-90,-47,8):
  asset("street:street_light",Vector3(x,0,59),p)
  asset("street:flower_planter",Vector3(x+2,0,61),p)
  asset("city:bench",Vector3(x+4,0,61),p)
 for x in range(-91,-47,3):asset("dune_grass",Vector3(x,0,65+sin(x*.2)),p)
 for x in [-80,-62]:
  asset("umbrella_ochre",Vector3(x,0,74),p);asset("beach_lounger",Vector3(x+1.5,0,74),p,PI);asset("beach_towel",Vector3(x-1.2,0,75),p)
 for grid in [terrain,ground]:
  var lib=grid.mesh_library.duplicate(true)
  for id in lib.get_item_list():
   if lib.get_item_name(id)=="sidewalk":
    var mesh=lib.get_item_mesh(id).duplicate(true)
    for surface in mesh.get_surface_count():
     var mat=mesh.surface_get_material(surface)
     if mat is StandardMaterial3D:
      mat=mat.duplicate();mat.albedo_texture=load("res://assets/models/city/street_mobility/textures/warm_pavers.png");mat.albedo_color=Color(.88,.85,.79);mesh.surface_set_material(surface,mat)
    lib.set_item_mesh(id,mesh)
  grid.mesh_library=lib
func landscape():
 var p=node("WestGardens",expansion)
 var rng=RandomNumberGenerator.new();rng.seed=83241
 for x in range(-90,-14,5):
  for z in range(-69,56,6):
   var point=Vector2(x,z)
   if Rect2(-82,-57,66,61).has_point(point) or z>15 and z<29:continue
   var blocked=false
   for b in district.get_children():
    if b.get_meta("district_scenery",false) and helper.bounds(b).grow(4.5).has_point(point):blocked=true
   if blocked or rng.randf()<.25:continue
   asset("tree:meadow_oak_broad" if x%3==0 else "tree:meadow_oak",Vector3(x+rng.randf_range(-1.2,1.2),0,z),p,rng.randf()*TAU)
   asset("plant:flowers_daisy",Vector3(x+1.5,0,z+1.6),p)
func run():
 district=load(BACKUP+"meadow_restaurant_district.tscn").instantiate();root.add_child(district);ground=district.get_node("MeadowBlocks");ground.mesh_library=ground.mesh_library.duplicate(true)
 var coast=district.get_node("CoastalQuarter");var parent=coast.get_parent();var at=coast.transform;coast.free();coast=load(BACKUP+"meadow_waterfront.tscn").instantiate();coast.transform=at;parent.add_child(coast);coast.name="CoastalQuarter"
 district.get_node("Place_005").position+=Vector3(108,0,-46)
 district.get_node("Place_011").position+=Vector3(60,0,-8)
 expansion=node("MeadowExpansion",district);expansion.set_meta("park_layout",true)
 clear_region(Rect2(-90,-72,72,88));clear_region(Rect2(20,-56,24,22))
 tile_rect(Rect2(-94,-76,186,22),"grass")
 tile_rect(Rect2(-94,-54,46,110),"grass")
 tile_rect(Rect2(-82,-56,64,60),"sidewalk")
 tile_rect(Rect2(-82,-52,10,56),"road_asphalt")
 tile_rect(Rect2(-94,18,46,8),"road_asphalt")
 tile_rect(Rect2(-94,16,46,2),"sidewalk");tile_rect(Rect2(-94,26,46,2),"sidewalk")
 tile_rect(Rect2(-18,-56,6,74),"sidewalk")
 for x in range(-6,-3):
  for z in range(-38,-27):ground.set_cell_item(Vector3i(x,0,z),ground.get_cell_item(Vector3i(x,0,-26)),ground.get_cell_item_orientation(Vector3i(x,0,-26)))
 tile_rect(Rect2(-14,-76,2,20),"sidewalk");tile_rect(Rect2(-6,-76,2,22),"sidewalk")
 for b in [district.get_node("Place_005"),district.get_node("Place_011")]:
  for part in b.find_children("*","Node3D",true,false):
   if part.get_meta("terrain_block",false) and absf(part.global_position.y+2)<.01:ground.set_cell_item(Vector3i(floori(part.global_position.x/2),0,floori(part.global_position.z/2)),-1)
 var b=mall()
 for x in range(-34,-10):
  for z in range(-27,-18):ground.set_cell_item(Vector3i(x,0,z),-1)
 plaza();parking();landscape();coast_details()
 var chapel=recipe("chapel_assembly",Vector3(84,0,-41),expansion,PI);remove_floor_ground(chapel,ground);save(chapel,"res://scenes/meadow/meadow_chapel.tscn")
 save(expansion,"res://scenes/meadow/meadow_expansion.tscn")
 var transform=expansion.transform;expansion.free();expansion=load("res://scenes/meadow/meadow_expansion.tscn").instantiate();district.add_child(expansion);expansion.transform=transform
 coast.free();coast=ResourceLoader.load("res://scenes/coast/meadow_waterfront.tscn", "PackedScene",ResourceLoader.CACHE_MODE_REPLACE).instantiate();district.add_child(coast);coast.name="CoastalQuarter"
 own(district,district);save(district,"res://scenes/world/meadow_restaurant_district.tscn")
 FileAccess.open("res://output/meadow_scene_integration/placements.json",FileAccess.WRITE).store_string(JSON.stringify({"placed":placed,"instances":serial,"tile_units":32},"\t"))
 print("MEADOW_ASSEMBLED ",serial);quit()
