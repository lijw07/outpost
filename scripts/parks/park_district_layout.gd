extends RefCounted

const PARK_RECT := Rect2(0,-24,24,16)

func bounds(node: Node3D) -> Rect2:
	var result := AABB()
	var found := false
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh==null:continue
		var box: AABB=mesh.global_transform*mesh.mesh.get_aabb()
		result=result.merge(box) if found else box
		found=true
	return Rect2(result.position.x,result.position.z,result.size.x,result.size.z)

func apply(district: Node3D) -> void:
	var ground: GridMap=district.get_node("MeadowBlocks")
	for child in district.get_children():
		if child.get_meta("park_layout",false) and child.name in ["MeadowCommonsPark","MeadowUnderstory"]:child.free()
		elif child is Node3D and not child is GridMap and not child.get_meta("district_scenery",false) and not child.get_meta("park_layout",false):
			if bounds(child).intersects(PARK_RECT.grow(.35)) or bounds(child).intersects(Rect2(-4,-18,4,2)) or bounds(child).intersects(Rect2(10,-8,4,2)):child.free()
	for x in 12:
		for z in range(-12,-4):ground.set_cell_item(Vector3i(x,0,z),-1)
	var dirt := -1
	for id in ground.mesh_library.get_item_list():
		if ground.mesh_library.get_item_name(id)=="dirt":dirt=id
	assert(dirt>=0)
	for x in [-2,-1]:ground.set_cell_item(Vector3i(x,0,-9),dirt)
	var park: Node3D=load("res://scenes/parks/meadow_commons.tscn").instantiate()
	park.name="MeadowCommonsPark"
	park.position=Vector3(0,0,-24)
	park.set_meta("park_layout",true)
	district.add_child(park)
	park.owner=district
	_landscape(district,ground)

func _landscape(district: Node3D, ground: GridMap) -> void:
	var group := Node3D.new()
	group.name="MeadowUnderstory"
	group.set_meta("park_layout",true)
	district.add_child(group)
	group.owner=district
	var obstacles: Array[Rect2]=[PARK_RECT.grow(.5),Rect2(-4,-18,4,2),Rect2(10,-8,4,2),Rect2(-4,-4,44,20)]
	for child in district.get_children():
		if child==group or child==ground or child.get_meta("park_layout",false):continue
		if child.get_meta("streetscape",false):
			for detail in child.get_children():
				obstacles.append(bounds(detail).grow(.25))
			continue
		if child is Node3D:
			var rect := bounds(child)
			if "oak" in child.scene_file_path:
				rect=Rect2(Vector2(child.position.x,child.position.z)-Vector2.ONE*.5,Vector2.ONE)
			obstacles.append(rect.grow(.25))
	var report=preload("res://scripts/parks/meadow_groundcover.gd").new().fill(group,ground,obstacles,district,735104)
	group.set_meta("prop_count",report.instances)
	print("MEADOW_UNDERSTORY ",report)
