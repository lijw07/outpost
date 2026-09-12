extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func localize(node: Node, building: Node) -> void:
	node.scene_file_path = ""
	node.owner = building
	for child in node.get_children():
		localize(child, building)

func _run() -> void:
	var patches: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://output/buildings/validation/wall_patches.json"))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scenes/buildings/catalog.json"))
	for entry in catalog.buildings:
		var building: Node3D = load(entry.scene).instantiate()
		root.add_child(building)
		var localized := {}
		for patch in patches[entry.id]:
			var visual: MeshInstance3D = building.get_node(patch.node)
			var module: Node = building.get_node(patch.asset)
			if not localized.has(patch.asset):
				module.set_meta("module_source", module.scene_file_path)
				localize(module, building)
				localized[patch.asset] = module
			var mesh := ArrayMesh.new()
			for surface_index in patch.surfaces.size():
				var faces: Array = patch.surfaces[surface_index]
				if faces.is_empty():
					continue
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_material(visual.get_active_material(surface_index))
				for face in faces:
					for point in face:
						st.set_uv(Vector2(point[3],point[4]))
						st.add_vertex(visual.to_local(Vector3(point[0],point[1],point[2])))
				st.generate_normals()
				st.commit(mesh)
			visual.mesh = mesh
		for module in localized.values():
			for body in module.find_children("*", "CollisionObject3D", true, false):
				var points := PackedVector3Array()
				for visual in body.find_children("*", "MeshInstance3D", true, false):
					for point in visual.mesh.get_faces():
						points.append(body.to_local(visual.to_global(point)))
				for collision in body.get_children():
					if collision is CollisionShape3D:
						var shape := ConcavePolygonShape3D.new()
						shape.backface_collision = true
						shape.set_faces(points)
						collision.shape = shape
						collision.transform = Transform3D.IDENTITY
		var packed := PackedScene.new()
		assert(packed.pack(building) == OK)
		assert(ResourceSaver.save(packed,entry.scene) == OK)
		building.free()
	print("WALL_JUNCTIONS_REPAIRED")
	quit()
