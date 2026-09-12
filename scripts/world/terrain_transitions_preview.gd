extends Node3D

const Transitions := preload("res://scripts/world/terrain_transitions.gd")
var transitions := Transitions.new()
var before: GridMap
var after: GridMap
var camera: Camera3D
var orbit := 0.0
var target := Vector3(14,0,12)
var compare := false
var caption: Label

func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("252e29")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c4c5ad")
	environment.environment.ambient_light_energy = 0.8
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-30,0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)
	before = sample_grid()
	before.name = "OriginalBlocks"
	add_child(before)
	after = sample_grid()
	after.name = "JoinedBlocks"
	add_child(after)
	transitions.apply_grid(after)
	before.visible = false
	before.collision_layer = 0
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 38
	camera.current = true
	add_child(camera)
	_update_camera()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(22,22)
	canvas.add_child(panel)
	caption = Label.new()
	caption.add_theme_font_size_override("font_size",20)
	panel.add_child(caption)
	_update_caption()
	if "--capture-transitions" in OS.get_cmdline_user_args():
		_capture()

func sample_grid() -> GridMap:
	var library := MeshLibrary.new()
	var ids := ["grass","dirt","sidewalk","road_asphalt","road_lane","sand","gravel","road_crossing"]
	for i in ids.size():
		var source: Node3D = load(preload("res://scripts/world/block_library.gd").scene_path(ids[i])).instantiate()
		add_child(source)
		var merged := ArrayMesh.new()
		for visual in source.find_children("*","MeshInstance3D",true,false):
			for surface in visual.mesh.get_surface_count():
				var st := SurfaceTool.new()
				st.append_from(visual.mesh,surface,visual.global_transform)
				st.set_material(visual.get_active_material(surface))
				st.commit(merged)
		library.create_item(i)
		library.set_item_name(i,ids[i])
		library.set_item_mesh(i,merged)
		library.set_item_shapes(i,[merged.create_trimesh_shape(),Transform3D.IDENTITY])
		source.free()
	var grid := GridMap.new()
	grid.mesh_library = library
	grid.cell_size = Vector3(2,2,2)
	grid.cell_center_y = false
	grid.position.y = -2
	for z in 14:
		for x in 16:
			var id := 0
			if z in [9,10,11]:
				id = 4 if z == 10 else 3
				if x == 9:
					id = 7
			elif z in [8,12]:
				id = 2
			elif (x in [4,5] and z in [1,2,3,4,5]) or (z in [4,5] and x in [6,7,8,9]) or (x == 9 and z in [6,7]):
				id = 1
			elif x in [11,12,13] and z in [1,2,3,4]:
				id = 5
			elif x in [12,13,14,15] and z in [6,7]:
				id = 6
			grid.set_cell_item(Vector3i(x,0,z),id)
	return grid

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_B:
			compare = not compare
			before.visible = compare
			after.visible = not compare
			_update_caption()
		elif event.keycode == KEY_Q:
			orbit -= PI/8
		elif event.keycode == KEY_E:
			orbit += PI/8
		elif event.keycode == KEY_1:
			target = Vector3(14,0,12); camera.size = 38
		elif event.keycode == KEY_2:
			target = Vector3(17,0,17); camera.size = 14
		elif event.keycode == KEY_3:
			target = Vector3(12,0,8); camera.size = 16
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(6,camera.size-2)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(48,camera.size+2)
	_update_camera()

func _update_camera() -> void:
	camera.position = target + Vector3(5,25,28).rotated(Vector3.UP,orbit)
	camera.look_at(target)

func _update_caption() -> void:
	caption.text = "  TERRAIN JOINS  /  " + ("ORIGINAL" if compare else "TRANSITIONS") + "  \n  B  Before / after    1  Overview    2  Street    3  Paths\n  Q / E  Orbit    Scroll  Zoom  "

func _capture() -> void:
	for view in [{"id":"overview","target":Vector3(15,0,13),"size":37.0},{"id":"street","target":Vector3(17,0,18),"size":15.0},{"id":"paths","target":Vector3(13,0,8),"size":18.0}]:
		target = view.target
		camera.size = view.size
		_update_camera()
		for original in [true,false]:
			compare = original
			before.visible = original
			after.visible = not original
			_update_caption()
			for frame in 4:
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://output/terrain_transitions/review/"+view.id+("_before" if original else "_after")+".png")
	get_tree().quit()
