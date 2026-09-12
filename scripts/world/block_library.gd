extends RefCounted

const BASE := "res://assets/models/blocks/"
const ATLAS := "res://assets/models/shared/textures/terrain_atlas.png"
const NAMES := {"grass":"grass_block", "grass_flowers":"grass_flowers_block", "dirt":"dirt_block", "sand":"sand_block", "stone":"stone_block", "gravel":"gravel_block", "sidewalk":"sidewalk_block", "road_asphalt":"road_block", "road_lane":"road_lane_block", "road_crossing":"road_crossing_block", "floor_wood":"floor_wood_block", "floor_tile":"floor_tile_block", "floor_concrete":"floor_concrete_block", "floor_carpet":"floor_carpet_block", "floor_bath_tile":"floor_bath_tile_block", "floor_shop_tile":"floor_shop_tile_block", "floor_clinic_tile":"floor_clinic_tile_block", "floor_concrete_worn":"floor_concrete_worn_block"}
const ROWS := {"grass":0,"grass_flowers":1,"dirt":2,"sand":3,"stone":4}
var images: Dictionary = {}
var atlas: Image

static func type_for(id: String) -> String:
	for key in NAMES:
		if NAMES[key] == id:
			return key
	return id

static func scene_path(id: String) -> String:
	return BASE + "scenes/" + NAMES.get(type_for(id),id) + ".tscn"

static func supports(id: String) -> bool:
	return NAMES.has(type_for(id))

static func asset_path(id: String) -> String:
	return scene_path(id) if supports(id) else "res://assets/models/city/scenes/" + id + ".tscn"

func tile(id: String, side: bool = false) -> Image:
	id = type_for(id)
	var key := id + ("_side" if side else "_top")
	if images.has(key):
		return images[key]
	if atlas == null:
		atlas = (load(ATLAS) as Texture2D).get_image()
		if atlas.is_compressed():
			atlas.decompress()
		atlas.convert(Image.FORMAT_RGBA8)
	if ROWS.has(id):
		images[key] = atlas.get_region(Rect2i(32 if side else 0,ROWS[id]*32,32,32))
		return images[key]
	var stone := tile("stone",side)
	var result := stone.duplicate() as Image
	for y in 32:
		for x in 32:
			var color := stone.get_pixel(x,y)
			if id.begins_with("road"):
				color = Color("494841")
				var grain := posmod(x*37+y*61+x*y*7,53)
				if grain < 5:
					color = color.lightened(0.012)
				elif grain > 48:
					color = color.darkened(0.018)
				if not side and id == "road_lane" and y == 15 and x >= 9 and x <= 22:
					color = Color("d3a54e")
				elif not side and id == "road_crossing" and y % 8 < 4 and x >= 4 and x <= 27:
					color = Color("e4dec9")
			elif id == "sidewalk":
				color = Color("b9a58a")
				var grain := posmod(x*19+y*43+x*y*3,47)
				if grain < 4:
					color = color.lightened(0.018)
				elif grain > 42:
					color = color.darkened(0.018)
				if not side:
					var joint_x := (x + (8 if y / 16 == 1 else 0)) % 16
					var joint_y := y % 16
					color = color.lightened(0.018) if (x / 16 + y / 16) % 2 == 0 else color
					if joint_x == 0 or joint_y == 0:
						color = Color("93816c")
					elif joint_x == 1 or joint_y == 1:
						color = color.lightened(0.055)
			elif id == "gravel":
				color = stone.get_pixel((x*2)%32,(y*2)%32).lerp(tile("dirt").get_pixel(x,y),0.20)
			result.set_pixel(x,y,color)
	images[key] = result
	return result

static func mesh_for(id: String) -> ArrayMesh:
	var source: Node3D = load(scene_path(id)).instantiate()
	var mesh := ArrayMesh.new()
	_collect(source,Transform3D.IDENTITY,mesh)
	source.free()
	return mesh

static func _collect(node: Node, parent: Transform3D, mesh: ArrayMesh) -> void:
	var transform: Transform3D = parent * node.transform if node is Node3D else parent
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var st := SurfaceTool.new()
			st.append_from(node.mesh,surface,transform)
			st.set_material(node.get_active_material(surface))
			st.commit(mesh)
	for child in node.get_children():
		_collect(child,transform,mesh)
