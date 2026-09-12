extends SceneTree
var scene: Node3D
func _initialize() -> void:
	call_deferred("_run")
func piece(id: String, pos: Vector3, parent: Node, rot: float=0) -> Node3D:
	var node: Node3D=load(preload("res://scripts/world/block_library.gd").asset_path(id)).instantiate()
	node.position=pos
	node.rotation_degrees.y=rot
	parent.add_child(node)
	node.owner=scene
	return node
func group(label: String, parent: Node) -> Node3D:
	var node := Node3D.new()
	node.name=label
	parent.add_child(node)
	node.owner=scene
	return node
func _run() -> void:
	for spec in [["meadow_grand_hotel","MEADOW GRAND HOTEL",12,"plaster"],["meadow_residences","MEADOW RESIDENCES",6,"brick_red"]]:
		scene=Node3D.new()
		scene.name=String(spec[0]).to_pascal_case()
		scene.set_script(load("res://scripts/buildings/modular_building.gd"))
		scene.building_title=spec[1]
		scene.floor_count=spec[2]
		scene.set_meta("role","Furnished district landmark; upper-floor guest and elevator simulation is outside this restaurant prototype")
		var floors := group("Floors",scene)
		for level in int(spec[2]):
			var floor_node := group("Level%d"%level,floors)
			var foundation := group("Foundation",floor_node)
			var walls := group("Walls",floor_node)
			var props := group("Furniture",floor_node)
			var y: float=level*4
			for x in range(1,12,2):
				for z in range(1,10,2):piece("floor_shop_tile" if level==0 else "floor_carpet",Vector3(x,y-2,z),foundation)
				for z in [-.125,10.125]:
					var id: String="wall_"+spec[3]+"_window"
					if level==0 and x==5 and z<0:id="doorway_wood"
					var node := piece(id,Vector3(x,y,z),walls)
					if id=="doorway_wood":node.set_meta("building_door",true)
					piece("wall_"+spec[3]+"_solid",Vector3(x,y+2,z),walls)
			for z in range(1,10,2):
				for x in [-.125,12.125]:
					piece("wall_"+spec[3]+"_window",Vector3(x,y,z),walls,90)
					piece("wall_"+spec[3]+"_solid",Vector3(x,y+2,z),walls,90)
			if level==0:
				piece("reception_desk",Vector3(8,y,3),props)
				piece("desk_items",Vector3(8,y+1.565,3),props)
				piece("sofa",Vector3(3,y,6),props)
				piece("coffee_table",Vector3(3,y,4),props)
				piece("rug",Vector3(8,y+.004,6),props)
				piece("bookcase",Vector3(11,y,8),props,-90)
			elif level==1 and spec[2]==12:
				for x in [3,8]:
					for z in [3,7]:
						piece("table",Vector3(x,y,z),props)
						piece("dishes",Vector3(x,y+1.065,z),props)
						piece("chair",Vector3(x,y,z+1.35),props)
			else:
				for x in [2,8]:
					piece("bed",Vector3(x,y,4),props)
					piece("nightstand",Vector3(x+1.6,y,4.8),props)
					piece("wardrobe",Vector3(x,y,8.5),props)
					piece("desk",Vector3(x+2,y,8),props)
					piece("bath_sink",Vector3(x+2,y,1),props)
		var roof := group("Roof",scene)
		for x in range(1,12,2):
			for z in range(1,10,2):piece("roof_flat",Vector3(x,spec[2]*4+.008,z),roof)
		piece("roof_vent",Vector3(3,spec[2]*4+.2,4),roof)
		var area := Area3D.new()
		area.name="InteriorArea"
		scene.add_child(area)
		area.owner=scene
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size=Vector3(12,spec[2]*4,10)
		collision.shape=shape
		collision.position=Vector3(6,spec[2]*2,5)
		area.add_child(collision)
		collision.owner=scene
		var sign := Label3D.new()
		sign.text=spec[1]
		sign.position=Vector3(6,3.4,-.4)
		sign.font=load("res://assets/ui/font/outpost_pixel.ttf")
		sign.font_size=20
		sign.pixel_size=.02
		scene.add_child(sign)
		sign.owner=scene
		for x in range(1,12,2):piece("sidewalk",Vector3(x,-2,-1),scene)
		var packed := PackedScene.new()
		assert(packed.pack(scene)==OK)
		assert(ResourceSaver.save(packed,"res://scenes/buildings/"+spec[0]+".tscn")==OK)
		scene.free()
	print("MEADOW_TOWERS_BUILT 12 and 6 floors")
	quit()
