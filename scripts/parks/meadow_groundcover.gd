extends RefCounted
const IDS := ["plants/grass_tufts","plants/grass_tufts_b","plants/grass_tufts","plants/flowers_daisy","plants/flowers_lavender","plants/grass_tufts_b","plants/fern","plants/tall_grass","rocks/rock_flat"]

func fill(parent: Node3D, ground: GridMap, obstacles: Array[Rect2], owner_root: Node, seed_value: int=31415) -> Dictionary:
	var meshes: Dictionary={}
	var transforms: Dictionary={}
	for id in IDS:
		if meshes.has(id):continue
		var source: Node3D=load("res://assets/models/test_library/scenes/"+id+".tscn").instantiate()
		parent.add_child(source)
		var mesh:=ArrayMesh.new()
		for visual in source.find_children("*","MeshInstance3D",true,false):
			for surface in visual.mesh.get_surface_count():
				var st:=SurfaceTool.new()
				st.append_from(visual.mesh,surface,source.global_transform.affine_inverse()*visual.global_transform)
				st.set_material(visual.get_active_material(surface))
				st.commit(mesh)
		meshes[id]=mesh
		transforms[id]=[]
		source.free()
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed_value
	var patch_noise:=FastNoiseLite.new()
	patch_noise.seed=seed_value
	patch_noise.frequency=.12
	var covered:=0
	var occupied:=0
	var eligible:=0
	var instances:=0
	var positions: Array[Vector2]=[]
	for cell in ground.get_used_cells():
		var tile_id:=ground.get_cell_item(cell)
		if ground.mesh_library.get_item_name(tile_id).split(":")[0]!="grass":continue
		var center3:=parent.to_local(ground.to_global(ground.map_to_local(cell)))
		center3.y=0
		var center:=Vector2(center3.x,center3.z)
		eligible+=1
		var placed:=false
		var patch:=patch_noise.get_noise_2d(center.x,center.y)
		var choices: Array=["plants/grass_tufts","plants/grass_tufts_b","plants/tall_grass"]
		if patch>.13:choices=["plants/flowers_daisy","plants/flowers_lavender","plants/grass_tufts_b"]
		elif patch<-.13:choices=["plants/fern","plants/grass_tufts","rocks/rock_flat"]
		var requested:=2 if rng.randf()<.35 else 1
		for cluster in requested:
			for attempt in 24:
				var id: String=choices[rng.randi_range(0,choices.size()-1)] if attempt<18 else "plants/grass_tufts_b"
				var shift:=Vector2(rng.randf_range(-.78,.78),rng.randf_range(-.78,.78))
				var point:=center+shift
				var amount:=rng.randf_range(.72,1.06)
				var basis3:=Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*amount)
				var t:=Transform3D(basis3,Vector3(point.x,0,point.y))
				var box: AABB=t*meshes[id].get_aabb()
				var rect:=Rect2(box.position.x,box.position.z,box.size.x,box.size.z)
				if obstacles.any(func(blocked):return blocked.intersects(rect)):continue
				if positions.any(func(other):return other.distance_squared_to(point)<.65*.65):continue
				var on_grass:=true
				for corner in [rect.position,rect.end,Vector2(rect.position.x,rect.end.y),Vector2(rect.end.x,rect.position.y)]:
					var local:=ground.to_local(parent.to_global(Vector3(corner.x,0,corner.y)))
					var sample:=Vector3i(floori(local.x/2),0,floori(local.z/2))
					var sample_id:=ground.get_cell_item(sample)
					if sample_id<0 or ground.mesh_library.get_item_name(sample_id).split(":")[0]!="grass":on_grass=false;break
				if not on_grass:continue
				transforms[id].append(t)
				positions.append(point)
				placed=true
				instances+=1
				break
		if placed:covered+=1
		else:occupied+=1
	for id in transforms:
		var entries: Array=transforms[id]
		if entries.is_empty():continue
		var batch=preload("res://scripts/parks/groundcover_batch.gd").new()
		batch.placements.assign(entries)
		batch.name=id.replace("/","_")
		batch.multimesh=MultiMesh.new()
		batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		batch.multimesh.mesh=meshes[id]
		batch.multimesh.instance_count=entries.size()
		parent.add_child(batch)
		batch.owner=owner_root
		var body:=StaticBody3D.new()
		body.name=batch.name+"Collision"
		parent.add_child(body)
		body.owner=owner_root
		var shape: Shape3D=meshes[id].create_trimesh_shape()
		for i in entries.size():
			batch.multimesh.set_instance_transform(i,entries[i])
			var collision:=CollisionShape3D.new()
			collision.shape=shape
			collision.transform=entries[i]
			body.add_child(collision)
			collision.owner=owner_root
	var report:={"grass_tiles":eligible,"newly_planted_tiles":covered,"occupied_or_reserved_tiles":occupied,"instances":instances}
	parent.set_meta("coverage",report)
	return report
