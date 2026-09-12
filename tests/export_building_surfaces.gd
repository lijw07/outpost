extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scenes/buildings/catalog.json"))
	var data := {}
	for entry in catalog.buildings:
		var building: Node3D = load(entry.scene).instantiate()
		root.add_child(building)
		building.set_physics_process(false)
		if "--open-doors" in OS.get_cmdline_user_args():
			building.set_all_doors_open(true)
		var rows: Array = []
		for visual in building.find_children("*", "MeshInstance3D", true, false):
			var asset: Node = visual
			var cursor: Node = visual
			while cursor != building:
				if cursor.scene_file_path.begins_with("res://assets/models/city/scenes/") or cursor.has_meta("module_source"):
					asset = cursor
				cursor = cursor.get_parent()
			var triangles: Array = []
			var surfaces: Array = []
			for surface_index in visual.mesh.get_surface_count():
				var arrays: Array = visual.mesh.surface_get_arrays(surface_index)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var uvs = arrays[Mesh.ARRAY_TEX_UV]
				var indices = arrays[Mesh.ARRAY_INDEX]
				if indices == null or indices.size() == 0:
					indices = range(vertices.size())
				var faces: Array = []
				for i in range(0, indices.size(), 3):
					var face: Array = []
					var xyz: Array = []
					for j in 3:
						var index: int = indices[i+j]
						var point: Vector3 = visual.global_transform * vertices[index]
						var uv: Vector2 = uvs[index] if uvs != null else Vector2.ZERO
						face.append([point.x,point.y,point.z,uv.x,uv.y])
						xyz.append([point.x,point.y,point.z])
					faces.append(face)
					triangles.append(xyz)
				surfaces.append(faces)
			rows.append({"asset": str(building.get_path_to(asset)), "node":str(building.get_path_to(visual)), "triangles": triangles, "surfaces":surfaces})
		data[entry.id] = rows
		building.free()
	FileAccess.open("res://output/buildings/validation/surfaces.json", FileAccess.WRITE).store_string(JSON.stringify(data))
	print("BUILDING_SURFACES_EXPORTED")
	quit()
