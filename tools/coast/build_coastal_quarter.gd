extends SceneTree
const BLOCKS=preload("res://scripts/world/block_library.gd")
const HELPER=preload("res://scripts/parks/park_district_layout.gd")
var district: Node3D
var coast: Node3D
var props: Node3D
var ground: GridMap
var terrain: GridMap
var boardwalk: GridMap
var helper=HELPER.new()
var serial:=0
var library:=MeshLibrary.new()
var ids:={}
var exclusion: Array[Rect2]=[]
func _initialize() -> void:call_deferred("_run")
func asset(id: String, at: Vector3, turn: float=0.0, scale3: Vector3=Vector3.ONE) -> Node3D:
	var path:=BLOCKS.asset_path(id)
	if id.begins_with("plant:"):path="res://assets/models/test_library/scenes/plants/"+id.trim_prefix("plant:")+".tscn"
	if id.begins_with("tree:"):path="res://assets/models/test_library/scenes/trees/"+id.trim_prefix("tree:")+".tscn"
	if id.begins_with("rock:"):path="res://assets/models/test_library/scenes/rocks/"+id.trim_prefix("rock:")+".tscn"
	var node:Node3D=load(path).instantiate()
	node.name="CoastProp_%04d"%serial;serial+=1
	node.position=at;node.rotation.y=turn;node.scale=scale3
	props.add_child(node);node.owner=coast
	return node
func make_grid(label: String) -> GridMap:
	var grid:=GridMap.new()
	grid.name=label;grid.mesh_library=library;grid.cell_size=Vector3(2,2,2);grid.cell_center_y=false;grid.position.y=-2
	coast.add_child(grid);grid.owner=coast
	return grid
func shore(x: float) -> float:return 2.0*floorf((81.0-.16*x+3*sin(x*.08))/2.0)
func patch(rect: Rect2i, id: String, grid: GridMap=terrain) -> void:
	for x in range(rect.position.x,rect.end.x):
		for z in range(rect.position.y,rect.end.y):
			ground.set_cell_item(Vector3i(x,0,z),-1)
			grid.set_cell_item(Vector3i(x,0,z),ids[id])
func clear_props(rect: Rect2) -> void:
	for node in district.get_children():
		if node==coast or node is GridMap or node.get_meta("park_layout",false) or node.get_meta("district_scenery",false):continue
		if node is Node3D and helper.bounds(node).intersects(rect):node.free()
func building(id: String, at: Vector3) -> void:
	var node:Node3D=load("res://scenes/buildings/"+id+".tscn").instantiate()
	node.name="Coastal_"+id
	node.position=at
	if id=="cedar_cottage":node.rotation.y=PI;node.position+=Vector3(12,0,10)
	district.add_child(node);node.owner=district
	node.set_meta("coastal_scenery",true);node.set_meta("district_scenery",true)
	clear_props(helper.bounds(node).grow(.6))
	exclusion.append(helper.bounds(node).grow(.5))
	for part in node.find_children("*","Node3D",true,false):
		if part.get_meta("terrain_block",false) and absf(part.global_position.y+2)<.01:ground.set_cell_item(Vector3i(floori(part.global_position.x/2),0,floori(part.global_position.z/2)),-1)
func hedge(a: Vector2,b: Vector2) -> void:
	var length:=a.distance_to(b)
	var count:=maxi(1,ceili(length/1.65))
	for i in count+1:
		var p:=a.lerp(b,float(i)/count)
		asset("plant:bush_round",Vector3(p.x,0,p.y),i*1.73,Vector3(1.05,1.1,1.05))
func flowers(a: Vector2,b: Vector2) -> void:
	var count:=maxi(1,ceili(a.distance_to(b)/1.5))
	for i in count:
		var p:=a.lerp(b,(i+.5)/count)
		asset("plant:flowers_daisy" if i%3!=0 else "plant:flowers_lavender",Vector3(p.x,0,p.y),i*.72,Vector3.ONE*.8)
func fence(a: Vector2,b: Vector2) -> void:
	var along_x:=absf(a.x-b.x)>absf(a.y-b.y)
	var count:=roundi(a.distance_to(b)/2)
	for i in count:
		var p:=a.lerp(b,(i+.5)/count)
		asset("fence",Vector3(p.x,0,p.y),0 if along_x else PI/2,Vector3(1,.6,1))
func _run() -> void:
	var path:="res://scenes/world/meadow_restaurant_district.tscn"
	if not FileAccess.file_exists("res://output/coast/before_coastal_quarter.tscn"):DirAccess.copy_absolute(path,"res://output/coast/before_coastal_quarter.tscn")
	district=load(path).instantiate();root.add_child(district)
	ground=district.get_node("MeadowBlocks")
	for child in district.get_children():
		if child.get_meta("coastal_scenery",false):
			var grass_id:=0
			for id in ground.mesh_library.get_item_list():
				if ground.mesh_library.get_item_name(id)=="grass":grass_id=id;break
			for part in child.find_children("*","Node3D",true,false):
				if part.get_meta("terrain_block",false) and absf(part.global_position.y+2)<.01:ground.set_cell_item(Vector3i(floori(part.global_position.x/2),0,floori(part.global_position.z/2)),grass_id)
			child.free()
		elif child.name=="CoastalQuarter":child.free()
	_face_street()
	for id in ["grass","sand","sidewalk","floor_wood","gravel"]:
		var i:=ids.size();ids[id]=i
		var mesh:=BLOCKS.mesh_for(id)
		library.create_item(i);library.set_item_name(i,id);library.set_item_mesh(i,mesh);library.set_item_shapes(i,[mesh.create_trimesh_shape(),Transform3D.IDENTITY])
	coast=Node3D.new();coast.set_script(preload("res://scripts/coast/coastal_quarter.gd"));coast.name="CoastalQuarter";coast.set_meta("park_layout",true)
	district.add_child(coast)
	props=Node3D.new();props.name="GardensAndStreetFurniture";coast.add_child(props);props.owner=coast
	terrain=make_grid("CoastalTerrain")
	boardwalk=make_grid("TimberPier")
	clear_props(Rect2(-48,55.8,140,60))
	clear_props(Rect2(46,28,4,32))
	clear_props(Rect2(76,28,14,30))
	building("lantern_restaurant",Vector3(-20,0,34))
	building("cedar_cottage",Vector3(76,0,2))
	patch(Rect2i(23,14,2,16),"sidewalk")
	patch(Rect2i(38,14,7,16),"sidewalk")
	var water_mesh:=ArrayMesh.new()
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-24,46):
		var beach_end:=roundi(shore(x*2+1)/2)
		for z in range(28,56):
			ground.set_cell_item(Vector3i(x,0,z),-1)
			if z>=beach_end:continue
			var dune_end:=32+roundi(sin(x*.27)*1.4)
			var id:="sidewalk" if z<30 else ("grass" if z<dune_end else "sand")
			terrain.set_cell_item(Vector3i(x,0,z),ids[id])
		var corners:=[Vector3(x*2,-.16,beach_end*2),Vector3(x*2+2,-.16,beach_end*2),Vector3(x*2+2,-.16,220),Vector3(x*2,-.16,220)]
		for i in [0,2,1,0,3,2]:st.set_normal(Vector3.UP);st.add_vertex(corners[i])
	st.commit(water_mesh)
	var water:=MeshInstance3D.new();water.name="MeadowBay";water.mesh=water_mesh
	var material:=ShaderMaterial.new();material.shader=load("res://scripts/coast/pixel_water.gdshader");water.material_override=material
	coast.add_child(water);water.owner=coast
	patch(Rect2i(30,29,3,17),"floor_wood",boardwalk)
	patch(Rect2i(24,42,15,3),"floor_wood",boardwalk)
	patch(Rect2i(30,46,3,5),"floor_wood",boardwalk)
	patch(Rect2i(29,37,9,6),"floor_wood",boardwalk)
	for cell in boardwalk.get_used_cells():terrain.set_cell_item(cell,-1)
	var hut:Node3D=load("res://scenes/buildings/cedar_cottage.tscn").instantiate()
	hut.name="HarborCottage";hut.building_title="Harbor Office";hut.position=Vector3(74,0,86);hut.rotation.y=PI;coast.add_child(hut);hut.owner=coast
	for label in hut.find_children("*","Label3D",true,false):label.text="HARBOR OFFICE"
	for part in hut.find_children("*","Node3D",true,false):
		if part.get_meta("terrain_block",false) and absf(part.global_position.y+2)<.01:boardwalk.set_cell_item(Vector3i(floori(part.global_position.x/2),0,floori(part.global_position.z/2)),-1)
	fence(Vector2(60,62),Vector2(60,72));fence(Vector2(66,62),Vector2(66,72))
	fence(Vector2(48,90),Vector2(60,90));fence(Vector2(66,90),Vector2(78,90));fence(Vector2(48,84),Vector2(48,90));fence(Vector2(78,84),Vector2(78,90))
	fence(Vector2(60,92),Vector2(60,102));fence(Vector2(66,92),Vector2(66,102));fence(Vector2(60,102),Vector2(66,102))
	for p in [Vector2(48,84),Vector2(48,90),Vector2(78,84),Vector2(78,90),Vector2(60,94),Vector2(66,94),Vector2(60,102),Vector2(66,102)]:asset("pillar",Vector3(p.x,-1.6,p.y))
	for x in [-38,-22,-6,10,26,42,58,74,86]:asset("street_lamp",Vector3(x,0,59),PI/2)
	for x in [-30,-12,8,28,44,82]:asset("bench",Vector3(x,0,60.9),0)
	for x in range(-38,88,2):
		if x in [-26,-24,10,12,46,48,60,62,64,78,80]:continue
		asset("fence",Vector3(x+1,0,61.8),0,Vector3(1,.55,1))
	for x in [-25,11,47,79]:
		var depth:=int(shore(x)-64)
		patch(Rect2i(floori(x/2),30,2,maxi(2,depth/2-2)),"sand")
	var rng:=RandomNumberGenerator.new();rng.seed=817721
	for i in 75:
		var x:=rng.randf_range(-46,89)
		if x>45 and x<80:continue
		var z:=shore(x)+rng.randf_range(-2.1,.9)
		asset("rock:"+(["boulder_large","boulder_mossy","boulder_small","rock_pile"][i%4]),Vector3(x,-.08,z),rng.randf()*TAU,Vector3.ONE*rng.randf_range(.7,1.25))
	for p in [Vector2(-28,72),Vector2(-10,75),Vector2(12,71),Vector2(32,69)]:
		asset("table",Vector3(p.x,0,p.y));asset("chair",Vector3(p.x-1.5,0,p.y),PI/2);asset("chair",Vector3(p.x+1.5,0,p.y),-PI/2)
		asset("shop_awning",Vector3(p.x,2.5,p.y),0,Vector3(1.7,1,1.7))
		for dx in [-1.5,1.5]:asset("pillar",Vector3(p.x+dx,0,p.y),0,Vector3(.6,1.25,.6))
	asset("dry_fountain",Vector3(83,0,45))
	for z in [33,39,51,55]:asset("bench",Vector3(77.2,0,z),PI/2)
	for z in [30,38,50,56]:asset("street_lamp",Vector3(89,0,z),PI)
	_hedged_gardens()
	_richer_canopy()
	_planter_borders()
	_visitors()
	var building_bounds:Array[Rect2]=[]
	for node in district.get_children():
		if node.get_meta("district_scenery",false):building_bounds.append(helper.bounds(node))
	for node in props.get_children():
		if "/trees/" in node.scene_file_path:
			var canopy:=helper.bounds(node)
			if building_bounds.any(func(rect):return rect.intersects(canopy)):node.free()
	var cover:=Node3D.new();cover.name="DunePlanting";coast.add_child(cover);cover.owner=coast
	var coast_obstacles:Array[Rect2]=[]
	for node in props.get_children():coast_obstacles.append(helper.bounds(node).grow(.1))
	preload("res://scripts/parks/meadow_groundcover.gd").new().fill(cover,terrain,coast_obstacles,coast,572413)
	preload("res://scripts/world/terrain_transitions.gd").new().apply_grid(terrain)
	var old=district.get_node_or_null("MeadowUnderstory");if old!=null:old.free()
	helper._landscape(district,ground)
	var packed:=PackedScene.new();assert(packed.pack(coast)==OK);assert(ResourceSaver.save(packed,"res://scenes/coast/meadow_waterfront.tscn")==OK)
	coast.free()
	var instance:Node3D=load("res://scenes/coast/meadow_waterfront.tscn").instantiate();district.add_child(instance);instance.owner=district
	preload("res://scripts/world/meadow_streetscape.gd").new().apply(district)
	var scene:=PackedScene.new();assert(scene.pack(district)==OK);assert(ResourceSaver.save(scene,path)==OK)
	print("COAST_BUILT props=",serial," waterfront scene saved")
	quit()
func _hedged_gardens() -> void:
	helper=HELPER.new()
	hedge(Vector2(41.5,-4),Vector2(41.5,14))
	flowers(Vector2(0,-4.8),Vector2(39,-4.8))
	for rect in [Rect2(-34,-1,1,14),Rect2(-21,50,19,1),Rect2(50,14,14,1),Rect2(74,14,16,1)]:
		hedge(rect.position,rect.end)
	for pair in [[Vector2(-38,54),Vector2(-24,54)],[Vector2(-18,54),Vector2(-4,54)],[Vector2(0,54),Vector2(14,54)],[Vector2(54,54),Vector2(70,54)],[Vector2(75,28),Vector2(75,54)]]:
		hedge(pair[0],pair[1]);flowers(pair[0]+Vector2(0,1.5),pair[1]+Vector2(0,1.5))
	for p in [Vector2(-35,49),Vector2(-23,51),Vector2(-4,50),Vector2(10,50),Vector2(17,54),Vector2(51,50),Vector2(73,51),Vector2(73,30),Vector2(45,-19),Vector2(48,-6),Vector2(67,5),Vector2(67,12)]:
		asset("tree:meadow_oak_broad",Vector3(p.x,0,p.y),p.x*.5)

func _richer_canopy()->void:
	var rectangles:Array[Rect2]=[Rect2(-5,-5,46,22),HELPER.PARK_RECT.grow(.3),Rect2(46,28,4,34),Rect2(75,27,16,34)]
	for child in district.get_children():
		if child.get_meta("district_scenery",false):rectangles.append(helper.bounds(child).grow(.2))
	var rng:=RandomNumberGenerator.new();rng.seed=918552
	var points:Array[Vector2]=[]
	for attempt in 1600:
		var p:=Vector2(rng.randf_range(-45,89),rng.randf_range(-50,54))
		var cell:=Vector3i(floori(p.x/2),0,floori(p.y/2))
		var id:=ground.get_cell_item(cell)
		if id<0 or ground.mesh_library.get_item_name(id).split(":")[0]!="grass":continue
		if points.any(func(other):return other.distance_to(p)<3.0):continue
		var node:=asset("tree:"+(["meadow_oak_broad","meadow_oak","meadow_oak_tall"][points.size()%3]),Vector3(p.x,0,p.y),rng.randf()*TAU)
		var box:=helper.bounds(node)
		if rectangles.any(func(rect):return rect.intersects(box)):node.free();continue
		points.append(p)
		if points.size()>=85:break
	print("COAST_CANOPY ",points.size())
func planter(p:Vector2)->void:
	for z in [-.55,.55]:asset("wall_brick_red_half",Vector3(p.x,0,p.y+z),0,Vector3(1,.45,1))
	for x in [-.875,.875]:asset("wall_brick_red_half",Vector3(p.x+x,0,p.y),PI/2,Vector3(.425,.45,1))
	asset("dirt",Vector3(p.x,0,p.y),0,Vector3(.75,.16,.425))
	asset("plant:flowers_daisy",Vector3(p.x,.32,p.y),p.x*.9,Vector3.ONE*.65)
func _planter_borders()->void:
	for x in range(1,40,3):planter(Vector2(x,-5.1))
	for x in [-37,-29,-20,-6,0,12,53,69]:planter(Vector2(x,55))
	for z in [30,36,42,48,54]:planter(Vector2(90.5,z))
	for x in [-30,-24,-17,43,51,69,75,87]:planter(Vector2(x,15))
func _visitors()->void:
	var people:=Node3D.new();people.name="PromenadeVisitors";coast.add_child(people);people.owner=coast
	var paths:=[
		[Vector3(-38,0,57),Vector3(-20,0,57)], [Vector3(-18,0,58.5),Vector3(2,0,58.5)],
		[Vector3(5,0,57),Vector3(25,0,57)], [Vector3(29,0,58.5),Vector3(45,0,58.5)],
		[Vector3(49,0,57),Vector3(60,0,57)], [Vector3(67,0,58.5),Vector3(85,0,58.5)],
		[Vector3(47,0,30),Vector3(47,0,54)], [Vector3(49,0,54),Vector3(49,0,32)],
		[Vector3(82,0,30),Vector3(82,0,40)], [Vector3(85,0,49),Vector3(85,0,57)],
		[Vector3(63,0,62),Vector3(63,0,71)], [Vector3(50,0,87),Vector3(59,0,87)],
		[Vector3(67,0,87),Vector3(76,0,87)], [Vector3(63,0,94),Vector3(63,0,100)],
		[Vector3(-36,0,17),Vector3(-17,0,17)], [Vector3(8,0,17),Vector3(23,0,17)],
		[Vector3(43,0,17),Vector3(61,0,17)], [Vector3(67,0,17),Vector3(88,0,17)],
		[Vector3(-20,0,73),Vector3(-15,0,76)], [Vector3(16,0,73),Vector3(26,0,72)]]
	for i in paths.size():
		var person=preload("res://scripts/coast/promenade_visitor.gd").new()
		person.name="Visitor_%02d"%i;person.route=PackedVector3Array(paths[i]);person.position=person.route[0].lerp(person.route[1],fmod(i*.37,.8));person.speed=.8+fmod(i*.17,.6)
		var sprite:=Sprite3D.new();sprite.name="Sprite";sprite.texture=load("res://assets/characters/"+("police" if i%7==0 else "survivor")+".png")
		sprite.hframes=4;sprite.pixel_size=.05;sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED;sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;sprite.position.y=.8;sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
		people.add_child(person);person.owner=coast;person.add_child(sprite);sprite.owner=coast

func _face_street()->void:
	var grass_id:=0
	for id in ground.mesh_library.get_item_list():
		if ground.mesh_library.get_item_name(id)=="grass":grass_id=id;break
	for node in district.get_children():
		if not is_instance_valid(node) or not node.get_meta("district_scenery",false):continue
		var target:=Vector3.ZERO
		if node.scene_file_path.ends_with("maple_family_house.tscn"):target=Vector3(-16,0,12)
		elif node.scene_file_path.ends_with("cedar_cottage.tscn"):target=Vector3(62,0,12)
		else:continue
		for part in node.find_children("*","Node3D",true,false):
			if part.get_meta("terrain_block",false) and absf(part.global_position.y+2)<.01:ground.set_cell_item(Vector3i(floori(part.global_position.x/2),0,floori(part.global_position.z/2)),grass_id)
		node.position=target;node.rotation.y=PI
		clear_props(helper.bounds(node).grow(.5))
		for part in node.find_children("*","Node3D",true,false):
			if part.get_meta("terrain_block",false) and absf(part.global_position.y+2)<.01:ground.set_cell_item(Vector3i(floori(part.global_position.x/2),0,floori(part.global_position.z/2)),-1)
