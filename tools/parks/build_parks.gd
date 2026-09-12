extends SceneTree
const TRANSITIONS=preload("res://scripts/world/terrain_transitions.gd")
var park: Node3D
var props: Node3D
var library: MeshLibrary
var serial := 0
var catalog: Array=[]
func _initialize() -> void:
	call_deferred("_run")
func group(label: String) -> Node3D:
	var node:=Node3D.new()
	node.name=label
	park.add_child(node)
	node.owner=park
	return node
func asset(id: String, x: float, z: float, rotation_y: float=0, y: float=0) -> Node3D:
	var path: String=preload("res://scripts/world/block_library.gd").asset_path(id)
	if id.begins_with("plant:"):path="res://assets/models/test_library/scenes/plants/"+id.trim_prefix("plant:")+".tscn"
	if id.begins_with("tree:"):path="res://assets/models/test_library/scenes/trees/"+id.trim_prefix("tree:")+".tscn"
	if id.begins_with("rock:"):path="res://assets/models/test_library/scenes/rocks/"+id.trim_prefix("rock:")+".tscn"
	var node: Node3D=load(path).instantiate()
	serial+=1
	node.name=id.replace(":","_").to_pascal_case()+"_%03d"%serial
	node.position=Vector3(x,y,z)
	node.rotation_degrees.y=rotation_y
	props.add_child(node)
	node.owner=park
	return node
func begin(id: String, title: String, w: int, d: int, paths: Array, material_id: String="dirt") -> void:
	park=Node3D.new()
	park.name=id.to_pascal_case()
	park.set_meta("park_id",id)
	park.set_meta("title",title)
	park.set_meta("footprint",Vector2(w*2,d*2))
	park.set_meta("placement","Walking surface Y=0, full terrain blocks extend to Y=-2. Replace underlying ground when placing.")
	root.add_child(park)
	serial=0
	var ground:=GridMap.new()
	ground.name="Ground"
	ground.mesh_library=library
	ground.cell_size=Vector3(2,2,2)
	ground.cell_center_y=false
	ground.position.y=-2
	park.add_child(ground)
	ground.owner=park
	for x in w:
		for z in d:ground.set_cell_item(Vector3i(x,0,z),["grass","dirt","sidewalk","gravel"].find(material_id) if Vector2i(x,z) in paths else 0)
	TRANSITIONS.new().apply_grid(ground)
	props=group("LandscapingAndFurniture")
	group("Entrances")
	group("Places")
	catalog.append({"id":id,"title":title,"scene":"res://scenes/parks/"+id+".tscn","tiles":[w,d],"world_size":[w*2,d*2]})
func marker(label: String,x: float,z: float, entrance: bool=false) -> void:
	var node:=Marker3D.new()
	node.name=label
	node.position=Vector3(x,0,z)
	park.get_node("Entrances" if entrance else "Places").add_child(node)
	node.owner=park
func flowers(x: float,z: float, type: String="flowers_daisy") -> void:
	asset("plant:"+type,x,z)
func save() -> void:
	_undergrowth()
	var packed:=PackedScene.new()
	assert(packed.pack(park)==OK)
	assert(ResourceSaver.save(packed,catalog[-1].scene)==OK)
	park.free()
func _run() -> void:
	library=MeshLibrary.new()
	var terrain: Array=["grass","dirt","sidewalk","gravel"]
	for i in terrain.size():
		var source: Node3D=load(preload("res://scripts/world/block_library.gd").scene_path(terrain[i])).instantiate()
		root.add_child(source)
		var mesh:=ArrayMesh.new()
		for visual in source.find_children("*","MeshInstance3D",true,false):
			for surface in visual.mesh.get_surface_count():
				var st:=SurfaceTool.new()
				st.append_from(visual.mesh,surface,visual.global_transform)
				st.set_material(visual.get_active_material(surface))
				st.commit(mesh)
		library.create_item(i)
		library.set_item_name(i,terrain[i])
		library.set_item_mesh(i,mesh)
		library.set_item_shapes(i,[mesh.create_trimesh_shape(),Transform3D.IDENTITY])
		source.free()
	var paths: Array=[]
	for x in 12:
		for z in 8:
			if z in [3,4] or x in [5,6] or (x>=4 and x<=7 and z>=2 and z<=5):paths.append(Vector2i(x,z))
	begin("meadow_commons","Meadow Commons",12,8,paths,"gravel")
	asset("dry_fountain",12,8)
	for point in [Vector2(3,3),Vector2(21,3),Vector2(3,13),Vector2(21,13)]:asset("tree:meadow_oak_young",point.x,point.y)
	for x in [7,17]:
		asset("bench",x,3,180)
		asset("bench",x,13)
		for z in [1,15]:flowers(x,z,"flowers_lavender")
	for x in [1,5,19,23]:
		for z in [1,15]:flowers(x,z)
	for x in [1,23]:
		for z in [5,11]:asset("plant:bush_round",x,z)
	asset("street_lamp",9,1)
	asset("street_lamp",15,15)
	marker("WestGate",1,7,true);marker("EastGate",23,7,true);marker("NorthGate",11,1,true);marker("SouthGate",11,15,true)
	marker("FountainWalk",8,8);marker("NorthSeating",7,5);marker("SouthSeating",17,11)
	save()
	paths=[]
	for x in 6:
		for z in 5:
			if x==2 or (z in [1,3] and x>=1 and x<=4):paths.append(Vector2i(x,z))
	begin("pocket_garden","Pocket Garden",6,5,paths)
	asset("tree:meadow_oak_young",2,5)
	asset("bench",9,5.8,90)
	for x in [1,3,7,9,11]:
		for z in [1,9]:flowers(x,z,"flowers_lavender" if x%4==1 else "flowers_daisy")
	asset("plant:fern",1,7);asset("plant:bush_berry",11,3)
	marker("NorthGate",5,1,true);marker("SouthGate",5,9,true);marker("ReadingBench",7,5)
	save()
	paths=[]
	for x in 8:
		for z in 6:
			if z==3 or (x in [1,2,5,6] and z in [1,2]):paths.append(Vector2i(x,z))
	begin("picnic_grove","Picnic Grove",8,6,paths)
	for x in [4,12]:
		asset("table",x,3.5)
		asset("dishes",x,3.5,0,1.065)
		asset("bench",x,2,180)
		asset("bench",x,5)
	for x in [3,13]:asset("tree:meadow_oak_young",x,10)
	asset("bench",8,10)
	for x in [1,7,9,15]:flowers(x,1);flowers(x,11,"flowers_lavender")
	asset("plant:fern",1,9);asset("plant:bush_berry",15,9)
	marker("WestGate",1,7,true);marker("EastGate",15,7,true);marker("PicnicA",4,7);marker("PicnicB",12,7);marker("GroveBench",8,8)
	save()
	paths=[]
	for x in 10:
		for z in [1,2]:paths.append(Vector2i(x,z))
	begin("wildflower_walk","Wildflower Walk",10,4,paths,"gravel")
	for x in [4,16]:asset("bench",x,1,180)
	for x in range(1,20,2):
		flowers(x,7,"flowers_lavender" if x%4==1 else "flowers_daisy")
		if x not in [3,5,15,17]:flowers(x,1,"flower_patch")
	for x in [1,19]:asset("plant:bush_berry",x,1)
	marker("WestGate",1,4,true);marker("EastGate",19,4,true);marker("FlowerBorder",10,5)
	save()
	paths=[Vector2i(3,0),Vector2i(3,1),Vector2i(3,2),Vector2i(4,2),Vector2i(5,2),Vector2i(5,3),Vector2i(5,4),Vector2i(4,4),Vector2i(3,4),Vector2i(3,5),Vector2i(3,6),Vector2i(3,7)]
	begin("woodland_retreat","Woodland Retreat",8,8,paths)
	for point in [Vector2(2,2),Vector2(14,2),Vector2(2,9),Vector2(14,13)]:asset("tree:meadow_oak_young",point.x,point.y)
	asset("tree:meadow_oak_tall",3,14)
	asset("bench",12,11)
	asset("rock:boulder_mossy",3,6)
	asset("rock:rock_flat",13,6)
	for point in [Vector2(1,4),Vector2(4,10),Vector2(15,8),Vector2(10,13),Vector2(9,2)]:
		asset("plant:fern",point.x,point.y)
		flowers(point.x+.6,point.y+.6)
	marker("NorthTrail",7,1,true);marker("SouthTrail",7,15,true);marker("RestingPlace",11,9)
	save()
	FileAccess.open("res://scenes/parks/catalog.json",FileAccess.WRITE).store_string(JSON.stringify({"parks":catalog},"\t"))
	print("PARKS_BUILT ",catalog.size())
	quit()

func _undergrowth() -> void:
	var ground: GridMap=park.get_node("Ground")
	var helper=preload("res://scripts/parks/park_district_layout.gd").new()
	var occupied: Array[Rect2]=[]
	for node in props.get_children():occupied.append(helper.bounds(node).grow(.1))
	for group_name in ["Entrances","Places"]:
		for node in park.get_node(group_name).get_children():occupied.append(Rect2(node.position.x-.5,node.position.z-.5,1,1))
	var cover:=group("Groundcover")
	preload("res://scripts/parks/meadow_groundcover.gd").new().fill(cover,ground,occupied,park,hash(park.name))
