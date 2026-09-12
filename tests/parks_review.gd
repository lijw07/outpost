extends SceneTree
var errors: Array=[]
var records: Array=[]
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1100,800)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("91a99a")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("d8e4cb")
	environment.environment.ambient_light_energy=.65
	viewport.add_child(environment)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-58,-28,0)
	light.light_color=Color("fff1cf")
	light.light_energy=.9
	light.shadow_enabled=true
	viewport.add_child(light)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	var capsule:=CapsuleShape3D.new()
	capsule.radius=.23
	capsule.height=1.4
	for entry in JSON.parse_string(FileAccess.get_file_as_string("res://scenes/parks/catalog.json")).parks:
		var park: Node3D=load(entry.scene).instantiate()
		viewport.add_child(park)
		var size2: Vector2=park.get_meta("footprint")
		var center:=Vector3(size2.x/2,0,size2.y/2)
		camera.position=center+Vector3(0,32,40.4969)
		camera.look_at(center)
		camera.size=maxf(size2.x*.9,size2.y*1.5)
		await physics_frame
		await physics_frame
		var space:=park.get_world_3d().direct_space_state
		var passable: Dictionary={}
		for x in range(1,int(size2.x*2)):
			for z in range(1,int(size2.y*2)):
				var foot:=Vector3(x*.5,0,z*.5)
				var ray:=PhysicsRayQueryParameters3D.create(foot+Vector3.UP*.12,foot-Vector3.UP*.12)
				if space.intersect_ray(ray).is_empty():continue
				var query:=PhysicsShapeQueryParameters3D.new()
				query.shape=capsule
				query.transform.origin=foot+Vector3.UP*.8
				if space.intersect_shape(query,1).is_empty():passable[Vector2i(x,z)]=true
		var first: Node3D=park.get_node("Entrances").get_child(0)
		var start:=Vector2i(roundi(first.position.x*2),roundi(first.position.z*2))
		var reached: Dictionary={}
		var queue: Array[Vector2i]=[]
		if passable.has(start):reached[start]=true;queue.append(start)
		var cursor:=0
		while cursor<queue.size():
			var cell:=queue[cursor]
			cursor+=1
			for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next: Vector2i=cell+delta
				if passable.has(next) and not reached.has(next):
					var sweep:=PhysicsShapeQueryParameters3D.new()
					sweep.shape=capsule
					sweep.transform.origin=Vector3(cell.x*.5,.8,cell.y*.5)
					sweep.motion=Vector3(delta.x*.5,0,delta.y*.5)
					if space.cast_motion(sweep)[0]<.999:continue
					reached[next]=true;queue.append(next)
		for group in ["Entrances","Places"]:
			for marker in park.get_node(group).get_children():
				var point:=Vector2i(roundi(marker.position.x*2),roundi(marker.position.z*2))
				if not reached.has(point):errors.append(entry.id+": inaccessible "+marker.name)
		var ground: GridMap=park.get_node("Ground")
		if ground.get_used_cells().size()!=int(entry.tiles[0]*entry.tiles[1]):errors.append(entry.id+": incomplete ground")
		for id in ground.mesh_library.get_item_list():
			var mesh:=ground.mesh_library.get_item_mesh(id)
			var shapes:=ground.mesh_library.get_item_shapes(id)
			if shapes.is_empty() or shapes[0].get_faces()!=mesh.get_faces():errors.append(entry.id+": ground collision differs")
		for batch in park.find_children("*","MultiMeshInstance3D",true,false):
			var body: Node= batch.get_parent().get_node(str(batch.name)+"Collision")
			if body.get_child_count()!=batch.multimesh.instance_count:errors.append(entry.id+": groundcover collision count differs")
			for i in batch.multimesh.instance_count:
				var collision: CollisionShape3D=body.get_child(i)
				if not collision.transform.is_equal_approx(batch.placements[i] if DisplayServer.get_name()=="headless" else batch.multimesh.get_instance_transform(i)) or not same_faces(collision.shape.get_faces(),batch.multimesh.mesh.get_faces()):errors.append(entry.id+": groundcover geometry differs")
		records.append({"id":entry.id,"reachable_samples":reached.size(),"ground_tiles":ground.get_used_cells().size()})
		if DisplayServer.get_name()!="headless":
			for i in 4:await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png("res://output/parks/review/"+entry.id+".png")
		park.free()
	var report:={"passed":errors.is_empty(),"errors":errors,"parks":records}
	FileAccess.open("res://output/parks/validation/parks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PARK_REVIEW ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)

func same_faces(a: PackedVector3Array,b: PackedVector3Array) -> bool:
	if a.size()!=b.size():return false
	for i in a.size():
		if a[i].distance_to(b[i])>.00001:return false
	return true
