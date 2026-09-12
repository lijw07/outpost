extends Control

const Model = preload("res://scripts/restaurant/restaurant_model.gd")
const SAVE_PATH := "user://meadow_restaurant_prototype_v1.json"
const CITY := "res://assets/models/city/scenes/"
var model = Model.new()
var viewport: SubViewport
var camera: Camera3D
var world: Node3D
var furnishings: Node3D
var floors_root: Node3D
var ghost: Node3D
var camera_target := Vector3(-19,0,26)
var zoom := 137.0
var drag := false
var build_mode := false
var selected := "dining"
var rotation_step := 0
var hover_cell := Vector2i(-99,-99)
var opened := true
var customers: Array[Dictionary] = []
var chefs: Array[Dictionary] = []
var waiter: Dictionary = {}
var spawn_clock := 1.0
var next_customer := 1
var furniture_nodes := {}
var hud: Control
var stats: Label
var notice: Label
var build_button: Button
var drawer: PanelContainer
var help_label: Label
var notice_time := 0.0
var previous_scale_mode: Window.ContentScaleMode
var previous_scale_factor: float
var no_save := false
var service_payments := 0
var neighboring_business: Node3D
var build_grid: MeshInstance3D
var ghost_material: StandardMaterial3D
var plot_hover := -1
var plot_hover_bounds := Rect2i()
var plot_overlay: MeshInstance3D
var plot_caption: Label3D
var last_ghost_cell := Vector2i(-999,-999)
var camera_bounds := Rect2(-48,-54,140,166)

func _ready() -> void:
	no_save = "--restaurant-test" in OS.get_cmdline_user_args()
	model.starter()
	if not no_save and FileAccess.file_exists(SAVE_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if data is Dictionary:
			var loaded = Model.new()
			if loaded.restore(data):model=loaded
	previous_scale_mode = get_window().content_scale_mode
	previous_scale_factor = get_window().content_scale_factor
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_factor = 1.0
	_setup_world()
	_build_ui()
	_rebuild_floors()
	_rebuild_furniture()
	_sync_chefs()
	waiter = _actor("survivor",Vector2i(2,4))
	waiter["target_customer"] = -1
	waiter["phase"]="idle"
	var tray := asset("dishes",Vector3(0,1.05,.35),waiter.node)
	tray.scale=Vector3.ONE*.5
	tray.visible=false
	for collision in tray.find_children("*","CollisionShape3D",true,false):collision.disabled=true
	waiter["tray"]=tray
	get_window().size_changed.connect(_resize_view)
	_resize_view()
	_update_ui()
	message("Welcome to The Little Table. Your first customers are on their way.")

func _exit_tree() -> void:
	_save()
	if get_window().size_changed.is_connected(_resize_view):get_window().size_changed.disconnect(_resize_view)
	get_window().content_scale_mode = previous_scale_mode
	get_window().content_scale_factor = previous_scale_factor

func _setup_world() -> void:
	viewport = $CityView/SubViewport
	world = $CityView/SubViewport/World
	camera = $CityView/SubViewport/Camera3D
	floors_root = $CityView/SubViewport/World/RestaurantFloor
	furnishings = $CityView/SubViewport/World/RestaurantFurniture
	_setup_map_limits()
	_setup_traffic()
	for label in world.find_children("*","Label3D",true,false):label.billboard=BaseMaterial3D.BILLBOARD_ENABLED

func _setup_traffic() -> void:
	var district := world.get_node("MeadowTown")
	for node in district.find_children("*","Node3D",true,false):
		if not is_instance_valid(node):continue
		if node.get_meta("asset_id","") in ["sedan","van","bus","ambulance"] and node.global_position.z>=18 and node.global_position.z<=26:node.free()
		elif node.get_script()!=null and String(node.get_script().resource_path).ends_with("district_visitor.gd"):node.add_to_group("town_pedestrians")
	var grid: GridMap=district.get_node("MeadowBlocks")
	var crossing_id := -1
	for id in grid.mesh_library.get_item_list():
		if grid.mesh_library.get_item_name(id).split(":")[0]=="road_crossing":crossing_id=id
	if crossing_id>=0:
		for z in range(9,13):grid.set_cell_item(Vector3i(2,0,z),crossing_id)
	var traffic := Node3D.new()
	traffic.name="TownTraffic"
	traffic.set_script(preload("res://scripts/vehicles/town_traffic.gd"))
	traffic.road_bounds=camera_bounds
	world.add_child(traffic)

func _setup_map_limits() -> void:
	var found := false
	for grid in world.get_node("MeadowTown").find_children("*","GridMap",true,false):
		for cell in grid.get_used_cells():
			var center: Vector3 = grid.to_global(grid.map_to_local(cell))
			var tile := Rect2(Vector2(center.x,center.z)-Vector2(grid.cell_size.x,grid.cell_size.z)/2,Vector2(grid.cell_size.x,grid.cell_size.z))
			camera_bounds = camera_bounds.merge(tile) if found else tile
			found = true
			var surface: String = grid.mesh_library.get_item_name(grid.get_cell_item(cell)).split(":")[0]
			if surface.begins_with("sidewalk") or surface.begins_with("road_"):
				model.public_cells[world_cell(center)] = true

	camera_bounds.size.y+=12.0

func asset(id: String, position3: Vector3, parent: Node, rot: int = 0) -> Node3D:
	var path := "res://assets/models/test_library/scenes/plants/bush_berry.tscn" if id=="planter" else preload("res://scripts/world/block_library.gd").asset_path(id)
	if id.begins_with("nature:"):path="res://assets/models/test_library/scenes/plants/"+id.trim_prefix("nature:")+".tscn"
	if id.begins_with("tree:"):path="res://assets/models/test_library/scenes/trees/"+id.trim_prefix("tree:")+".tscn"
	var node: Node3D = load(path).instantiate()
	node.position = position3
	node.rotation.y = -rot * PI/2
	parent.add_child(node)
	$CityView/SubViewport/World/ReferencePresentation.apply_to(node)
	return node

func _rebuild_floors() -> void:
	for child in floors_root.get_children():child.free()
	var district: Node3D=world.get_node("MeadowTown")
	var ground: GridMap=district.get_node("MeadowBlocks")
	var rect: Rect2i=model.land
	var region := Model.LAND_LIMIT
	for x in range(region.position.x,region.end.x):
		for z in range(region.position.y,region.end.y):
			var cell := Vector2i(x,z)
			var is_owned: bool=model.owned(cell)
			var reserved := Rect2i(0,0,20,6).has_point(cell) or Rect2i(12,6,8,1).has_point(cell)
			if not is_owned and not reserved:
				var tile_id:=ground.get_cell_item(Vector3i(x,0,z))
				if tile_id>=0 and ground.mesh_library.get_item_name(tile_id).split(":")[0]=="grass":_meadow_prop(x,z)
				continue
			if not model.business_owned and x>=13 and x<20 and z>=0 and z<=6:continue
			ground.set_cell_item(Vector3i(x,0,z),-1)
			var id: String=model.floors.get("%d,%d"%[x,z],"floor_wood") if is_owned else ("sidewalk" if z==6 and x>=13 else "grass")
			if id not in ["floor_wood","floor_shop_tile","grass","sidewalk"]:id="floor_wood"
			asset(id,Vector3(x*2+1,-2,z*2+1),floors_root)
			if id=="grass":_meadow_prop(x,z)
	_clear_owned_landscape(district)
	_sync_neighbor()
	_rebuild_shell()
	_rebuild_grid()

func _meadow_prop(x: int,z: int) -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=hash("meadow_%d_%d"%[x,z])
	var id: String=["grass_tufts","flowers_daisy","grass_tufts_b","flowers_lavender","fern"][rng.randi_range(0,4)]
	var node:=asset("nature:"+id,Vector3(x*2+1+rng.randf_range(-.38,.38),0,z*2+1+rng.randf_range(-.38,.38)),floors_root)
	node.rotation.y=rng.randf_range(0,TAU)
	node.scale=Vector3.ONE*rng.randf_range(.68,.9)

func _clear_owned_landscape(district: Node3D) -> void:
	var rect: Rect2i=model.land
	var footprint := Rect2(rect.position.x*2,rect.position.y*2,rect.size.x*2,rect.size.y*2)
	var helper=preload("res://scripts/parks/park_district_layout.gd").new()
	var props: Array=district.get_children()
	props.append_array(district.get_node("MeadowUnderstory").get_children())
	for prop in props:
		if not is_instance_valid(prop) or not prop is Node3D or prop is GridMap:continue
		if prop.get_meta("district_scenery",false) or prop.get_meta("park_layout",false):continue
		if helper.bounds(prop).intersects(footprint):prop.free()

func _rebuild_shell() -> void:
	var previous := world.get_node_or_null("RestaurantShell")
	if previous!=null:previous.free()
	var shell:=Node3D.new()
	shell.name="RestaurantShell"
	world.add_child(shell)
	var rect: Rect2i=model.land
	for x in range(rect.position.x,rect.end.x):
		asset("wall_wood_window" if posmod(x,2)==0 else "wall_wood_solid",Vector3(x*2+1,0,rect.position.y*2-.2),shell)
	for z in range(rect.position.y,rect.end.y):
		asset("wall_wood_window",Vector3(rect.position.x*2-.2,0,z*2+1),shell,1)
	var restaurant_sign:=_label3d("THE LITTLE TABLE",Vector3(rect.position.x+rect.end.x,2.6,rect.position.y*2-.4),Color("ffedb9"),false)
	shell.add_child(restaurant_sign)

func _rebuild_furniture() -> void:
	for child in furnishings.get_children():child.free()
	furniture_nodes.clear()
	for item in model.objects:
		var group := Node3D.new()
		group.name = "Furniture_%d" % item.id
		group.position = cell_world(item.cell)
		group.rotation.y = -item.rotation * PI/2
		furnishings.add_child(group)
		var placed := asset(Model.CATALOG[item.kind].asset,Vector3(1,0,1) if item.kind=="tree" else Vector3.ZERO,group)
		if item.kind=="door":placed.get_node("Hinge").rotation.y=PI/2
		if item.kind=="dining":
			var food := asset("dishes",Vector3(0,1.065,0),group)
			food.name="Food"
			food.visible=false
		furniture_nodes[item.id]=group
	for customer in customers:
		if customer.state=="eating":_food(customer.table,true)

func _label3d(text: String, pos: Vector3, color: Color, billboard: bool = true) -> Label3D:
	var label := Label3D.new()
	label.text=text
	label.position=pos
	label.font=load("res://assets/ui/font/outpost_pixel.ttf")
	label.font_size=18
	label.pixel_size=.020
	label.modulate=color
	label.outline_size=4
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	return label

func cell_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x*2+1,0,cell.y*2+1)

func world_cell(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x/2),floori(pos.z/2))

func _actor(sheet: String, cell: Vector2i) -> Dictionary:
	var node := Node3D.new()
	node.position=cell_world(cell)
	world.add_child(node)
	node.add_to_group("town_pedestrians")
	var sprite := Sprite3D.new()
	sprite.texture=load("res://assets/characters/"+sheet+".png")
	sprite.hframes=4
	sprite.pixel_size=.05
	sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.position.y=.8
	sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
	node.add_child(sprite)
	return {"node":node,"sprite":sprite,"route":[],"goal":cell}

func _sync_chefs() -> void:
	for chef in chefs:chef.node.free()
	chefs.clear()
	for item in model.objects:
		if item.kind=="stove":
			var cell: Vector2i = model.service_cell(item)
			var chef := _actor("police",cell)
			chef["stove"] = item.id
			chef["job"] = -1
			chefs.append(chef)

func _route(actor: Dictionary, goal: Vector2i) -> void:
	actor.goal=goal
	actor.route=model.path(world_cell(actor.node.position),goal)
	if not actor.route.is_empty():actor.route.pop_front()

func _walk(actor: Dictionary, delta: float) -> bool:
	if actor.route.is_empty():return true
	var target := cell_world(actor.route[0])
	var position3: Vector3=actor.node.position
	if target.z>=18 and target.z<=26 and (position3.z<18 or position3.z>26):
		if not world.get_node("TownTraffic").crossing_clear(target):return false
	var delta3: Vector3 = target-actor.node.position
	actor.sprite.frame = (1 if delta3.x>0 else 3) if absf(delta3.x)>absf(delta3.z) else (0 if delta3.z>0 else 2)
	actor.node.position=actor.node.position.move_toward(target,delta*3.6)
	if actor.node.position.distance_to(target)<.01:actor.route.pop_front()
	return actor.route.is_empty()

func _process(delta: float) -> void:
	var pan := Input.get_vector("move_left","move_right","move_up","move_down")
	if pan.length_squared()>0:
		var right := camera.basis.x
		var forward := Vector3(camera.basis.z.x,0,camera.basis.z.z).normalized()
		camera_target += (right*pan.x+forward*pan.y)*delta*22
	_update_camera()
	_update_plot_hover()
	if build_mode:_update_ghost()
	if not build_mode:
		_tick_service(delta)
	if notice_time>0:
		notice_time-=delta
		if notice_time<=0:notice.text=""
	_update_ui()

func _tick_service(delta: float) -> void:
	spawn_clock-=delta
	if opened and spawn_clock<=0:
		_spawn_customer()
		spawn_clock=5.0
	for chef in chefs:
		if chef.job<0:
			for customer in customers:
				if customer.state=="waiting":
					customer.state="cooking"
					customer["stove"]=chef.stove
					customer.timer=5.5
					chef.job=customer.id
					break
	for customer in customers.duplicate():
		match customer.state:
			"entering":
				if _walk(customer,delta):
					customer.state="waiting"
					customer.sprite.frame=posmod(2-_item(customer.chair).rotation,4)
					customer.sprite.position.y=1.05
			"cooking":
				customer.timer-=delta
				if customer.timer<=0:
					customer.state="ready"
					for chef in chefs:
						if chef.job==customer.id:chef.job=-1
			"eating":
				customer.timer-=delta
				if customer.timer<=0:
					var payment: int = 28
					model.coins+=payment
					model.earned+=payment
					model.served+=1
					service_payments+=1
					customer.state="leaving"
					customer.sprite.position.y=.8
					_food(customer.table,false)
					_route(customer,Model.STREET)
					_save()
			"leaving":
				if _walk(customer,delta):
					customer.node.queue_free()
					customers.erase(customer)
	if waiter.is_empty():return
	if waiter.target_customer<0 and _walk(waiter,delta):
		for customer in customers:
			if customer.state=="ready":
				customer.state="serving"
				waiter.target_customer=customer.id
				var stove := _item(customer.stove)
				_route(waiter,model.service_cell(stove))
				waiter.phase="pickup"
				break
	elif waiter.target_customer>=0 and _walk(waiter,delta):
		for customer in customers:
			if customer.id==waiter.target_customer:
				if waiter.phase=="pickup":
					waiter.phase="deliver"
					waiter.tray.visible=true
					_route(waiter,model.service_cell(_item(customer.table)))
					return
				customer.state="eating"
				customer.timer=5.0
				_food(customer.table,true)
		waiter.target_customer=-1
		waiter.phase="idle"
		waiter.tray.visible=false
		_route(waiter,Model.ENTRY)

func _item(id: int) -> Dictionary:
	for item in model.objects:
		if item.id==id:return item
	return {}

func _food(id: int, visible_food: bool) -> void:
	if furniture_nodes.has(id):furniture_nodes[id].get_node("Food").visible=visible_food

func _spawn_customer() -> bool:
	if chefs.is_empty():return false
	var occupied := {}
	for customer in customers:occupied[customer.table]=true
	for item in model.objects:
		if item.kind=="dining" and not occupied.has(item.id) and not model.table_chair(item).is_empty():
			var customer := _actor("survivor" if next_customer%2==0 else "soldier",Model.STREET)
			customer.merge({"id":next_customer,"table":item.id,"chair":model.table_chair(item).id,"state":"entering","timer":0.0})
			next_customer+=1
			customers.append(customer)
			_route(customer,model.seat(item))
			return true
	return false

func _resize_view() -> void:
	viewport.size=get_window().size
	$CityView.size=viewport.size
	if hud != null:
		hud.fit_viewport(Vector2(viewport.size))
	_update_camera()

func _update_camera() -> void:
	var viewing_direction:=Vector3(0,32,sqrt(38.0*38.0+14.0*14.0)).normalized()
	var aspect := float(viewport.size.x)/maxf(1,viewport.size.y)
	var safe_bounds := camera_bounds.grow(-1.0)
	var maximum_zoom := minf(150,minf(safe_bounds.size.x/aspect,safe_bounds.size.y*viewing_direction.y))
	zoom = clampf(zoom,minf(22,maximum_zoom),maximum_zoom)
	var half_view := Vector2(zoom*aspect/2,zoom/(2*viewing_direction.y))
	camera_target.x = clampf(camera_target.x,safe_bounds.position.x+half_view.x,safe_bounds.end.x-half_view.x)
	camera_target.z = clampf(camera_target.z,safe_bounds.position.y+half_view.y,safe_bounds.end.y-half_view.y)
	camera_target.y = 0
	camera.size=zoom
	camera.position=camera_target+viewing_direction*maxf(52,zoom*1.15+35)
	camera.look_at(camera_target)
	var units := zoom/maxf(1,viewport.size.y)
	var basis3 := camera.global_basis
	var projected: Vector3 = basis3.inverse()*camera.position
	projected.x=roundf(projected.x/units)*units
	projected.y=roundf(projected.y/units)*units
	camera.position=basis3*projected

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_MIDDLE:drag=event.pressed
		if event.pressed:
			if event.button_index==MOUSE_BUTTON_WHEEL_UP:zoom=maxf(22,zoom-2)
			elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:zoom=minf(150,zoom+2)
			elif event.button_index==MOUSE_BUTTON_RIGHT and build_mode:toggle_build()
			elif event.button_index==MOUSE_BUTTON_LEFT and build_mode:
				hover_cell=_pointer_cell(event.position)
				_commit_build()
			elif event.button_index==MOUSE_BUTTON_LEFT:
				_buy_pointed_plot()
	elif event is InputEventMouseMotion and drag:
		var right := camera.basis.x
		var forward := Vector3(camera.basis.z.x,0,camera.basis.z.z).normalized()
		camera_target-= (right*event.relative.x+forward*event.relative.y)*zoom/viewport.size.y
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_B:toggle_build()
		elif event.keycode==KEY_R and build_mode:rotation_step=posmod(rotation_step+1,4);_refresh_ghost()
		elif event.keycode==KEY_ESCAPE and build_mode:toggle_build()
		elif event.keycode==KEY_HOME:camera_target=Vector3(8,0,7);zoom=28

		elif event.keycode==KEY_M:camera_target=Vector3(-19,0,26);zoom=137
		elif event.keycode==KEY_V:camera_target=Vector3(28,0,76);zoom=75
		elif event.keycode==KEY_P:camera_target=Vector3(12,0,-16);zoom=32
		elif event.keycode==KEY_C:opened=not opened;message("Welcoming customers." if opened else "Closed to new arrivals; seated guests will finish.")

func _pointer_cell(at = null) -> Vector2i:
	var mouse: Vector2 = get_global_mouse_position() if at==null else at
	var ray := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var point = Plane(Vector3.UP,0).intersects_ray(ray,direction)
	return world_cell(point) if point != null else Vector2i(-99,-99)

func toggle_build() -> void:
	build_mode=not build_mode
	drawer.visible=build_mode
	if build_mode:_refresh_ghost()
	if is_instance_valid(build_grid):build_grid.visible=build_mode
	if not build_mode and is_instance_valid(ghost):ghost.queue_free();ghost=null
	message("Service paused. Place furniture, rotate with R, or reclaim items." if build_mode else "Service resumed. Your staff will take it from here.")
	_update_ui()

func _choose(id: String) -> void:
	selected=id
	rotation_step=0
	_refresh_ghost()
	_update_ui()

func _refresh_ghost() -> void:
	if is_instance_valid(ghost):ghost.free()
	last_ghost_cell=Vector2i(-999,-999)
	ghost=Node3D.new()
	world.add_child(ghost)
	if selected in ["erase","floor"]:
		var visual := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size=Vector3(1.96,.03,1.96)
		visual.mesh=box
		ghost.add_child(visual)
	else:
		asset(Model.CATALOG[selected].asset,Vector3(1,0,1) if selected=="tree" else Vector3.ZERO,ghost)
	for collision in ghost.find_children("*","CollisionShape3D",true,false):collision.disabled=true
	ghost.rotation.y=-rotation_step*PI/2
	ghost_material=StandardMaterial3D.new()
	ghost_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	for visual in ghost.find_children("*","MeshInstance3D",true,false):visual.material_override=ghost_material

func _build_error(cell: Vector2i) -> String:
	if not model.owned(cell):return "Buy Fern & Flour to expand onto this business plot." if cell.x>=12 and cell.x<20 and cell.y>=0 and cell.y<6 else "Buy this plot before building here."
	if selected in ["erase","floor"]:return ""
	var error: String = model.placement_error(selected,cell,rotation_step)
	if not error.is_empty():return error
	var item := {"id":-1,"kind":selected,"cell":cell,"rotation":rotation_step}
	var candidate: Array = model.objects.duplicate(true)
	candidate.append(item)
	var actors := customers+chefs
	if not waiter.is_empty():actors.append(waiter)
	for actor in actors:
		var at := world_cell(actor.node.position)
		if at in model.cells(item):return "Someone is standing here. Try another tile."
		if model.path(at,actor.goal,candidate).is_empty():return "Keep a clear route for customers and staff."
	return ""

func _update_ghost() -> void:
	if not is_instance_valid(ghost):return
	hover_cell=_pointer_cell()
	if hover_cell==last_ghost_cell:return
	last_ghost_cell=hover_cell
	ghost.visible=Model.LAND_LIMIT.has_point(hover_cell)
	ghost.position=cell_world(hover_cell)+Vector3.UP*.035
	var error := _build_error(hover_cell)
	var color := Color(.5,1,.72,.52) if error.is_empty() else Color(1,.28,.2,.55)
	ghost_material.albedo_color=color
	help_label.text=error if not error.is_empty() else ("Click to reclaim · 75% refund" if selected=="erase" else "Click to place · R rotate · Right click to finish")

func _commit_build() -> bool:
	var error := _build_error(hover_cell)
	if not error.is_empty():message(error);return false
	if selected=="floor":
		var key := "%d,%d" % [hover_cell.x,hover_cell.y]
		model.floors[key]="floor_wood" if model.floors.get(key,"floor_wood")=="floor_shop_tile" else "floor_shop_tile"
		_rebuild_floors()
	elif selected=="erase":
		var removed_stove := false
		for item in model.objects:
			if hover_cell in model.cells(item):
				removed_stove = item.kind=="stove"
				for customer in customers:
					if customer.table==item.id or customer.chair==item.id or item.kind=="stove":message("This is in use. Close the restaurant and let guests finish first.");return false
		if not model.remove_at(hover_cell):message("Choose furniture to reclaim.");return false
		_rebuild_furniture()
		if removed_stove:_sync_chefs()
	else:
		error=model.place(selected,hover_cell,rotation_step)
		if not error.is_empty():message(error);return false
		_rebuild_furniture()
		if selected=="stove":
			var item: Dictionary = model.objects[-1]
			var chef := _actor("police",model.service_cell(item))
			chef.merge({"stove":item.id,"job":-1})
			chefs.append(chef)
	for actor in customers+[waiter]:
		if not actor.route.is_empty():_route(actor,actor.goal)
	last_ghost_cell=Vector2i(-999,-999)
	_save()
	message("Floor updated." if selected=="floor" else "Layout updated. Your restaurant is taking shape.")
	return true

func _expand(edge: int=1) -> void:
	var error: String=model.expansion_error(edge)
	if not error.is_empty():message(error);return
	if model.expand(edge):
		_rebuild_floors()
		_save()
		message("One %s unlocked. Your restaurant is now %d × %d tiles."%["column" if edge<2 else "row",model.width(),model.height()])

func _save() -> void:
	if no_save:return
	var file := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if file != null:file.store_string(JSON.stringify(model.serialize(),"\t"))

func message(text: String) -> void:
	if notice != null:notice.text=text;notice_time=7

func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud = $RestaurantHUD
	hud.set_items(preload("res://scripts/restaurant/restaurant_ui_data.gd").catalog(Model.CATALOG))
	hud.build_toggled.connect(toggle_build)
	hud.item_requested.connect(_choose)
	stats = hud.stats
	build_button = hud.build_button
	drawer = hud.drawer
	notice = hud.notice
	help_label = hud.help_label

func _update_ui() -> void:
	hud.set_state({"coins": model.coins, "served": model.served, "building": build_mode, "open": opened, "selected": selected})
	build_button = hud.finish_button if build_mode else hud.build_button
	var capacity := 0
	for item in model.objects:
		if item.kind == "dining" and not model.table_chair(item).is_empty(): capacity += 1
	hud.set_orders(preload("res://scripts/restaurant/restaurant_ui_data.gd").orders(customers, model.objects), capacity, chefs.size(), 0 if waiter.is_empty() else 1)

func _rebuild_grid() -> void:
	if is_instance_valid(build_grid):build_grid.free()
	build_grid=MeshInstance3D.new()
	build_grid.name="BuildGrid"
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var rect: Rect2i=model.land
	for x in range(rect.position.x,rect.end.x+1):
		mesh.surface_add_vertex(Vector3(x*2,.025,rect.position.y*2))
		mesh.surface_add_vertex(Vector3(x*2,.025,rect.end.y*2))
	for z in range(rect.position.y,rect.end.y+1):
		mesh.surface_add_vertex(Vector3(rect.position.x*2,.025,z*2))
		mesh.surface_add_vertex(Vector3(rect.end.x*2,.025,z*2))
	mesh.surface_end()
	var grid_material := StandardMaterial3D.new()
	grid_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_material.albedo_color=Color("9dc797")
	build_grid.mesh=mesh
	build_grid.material_override=grid_material
	build_grid.visible=build_mode
	world.add_child(build_grid)

func _sync_neighbor() -> void:
	if model.business_owned:
		if is_instance_valid(neighboring_business):neighboring_business.free();neighboring_business=null
		return
	if is_instance_valid(neighboring_business):return
	neighboring_business=load("res://scenes/buildings/corner_grocery.tscn").instantiate()
	neighboring_business.name="FernAndFlourBusiness"
	neighboring_business.position=Vector3(40,0,12)
	neighboring_business.rotation.y=PI
	world.add_child(neighboring_business)
	neighboring_business.set_meta("purchase_cost",1200)
	for prop in neighboring_business.find_children("*","Node3D",true,false):
		if is_instance_valid(prop) and prop.get_meta("asset_id","")=="dumpster":prop.free()
	for label in neighboring_business.find_children("*","Label3D",true,false):
		label.text="FERN & FLOUR"
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED

func _plot_at(cell: Vector2i) -> int:
	for edge in 4:
		if model.expansion_strip(edge).has_point(cell):return edge
	return -1

func _pointed_plot() -> int:
	if build_mode:return -1
	var control := get_viewport().gui_get_hovered_control()
	if control != null and control != self and control != hud:return -1
	return _plot_at(_pointer_cell())

func _buy_pointed_plot() -> void:
	var index := _pointed_plot()
	if index<0:return
	_expand(index)
	_update_plot_hover()

func _update_plot_hover() -> void:
	var index := _pointed_plot()
	var strip: Rect2i=model.expansion_strip(index)
	if index!=plot_hover or strip!=plot_hover_bounds:
		plot_hover=index
		plot_hover_bounds=strip
		if is_instance_valid(plot_overlay):plot_overlay.free()
		if is_instance_valid(plot_caption):plot_caption.free()
		if index>=0:
			var mesh := ImmediateMesh.new()
			mesh.surface_begin(Mesh.PRIMITIVE_LINES)
			for x in range(strip.position.x,strip.end.x+1):
				mesh.surface_add_vertex(Vector3(x*2,.055,strip.position.y*2))
				mesh.surface_add_vertex(Vector3(x*2,.055,strip.end.y*2))
			for z in range(strip.position.y,strip.end.y+1):
				mesh.surface_add_vertex(Vector3(strip.position.x*2,.055,z*2))
				mesh.surface_add_vertex(Vector3(strip.end.x*2,.055,z*2))
			mesh.surface_end()
			plot_overlay=MeshInstance3D.new()
			plot_overlay.name="LandUnlockGrid"
			plot_overlay.mesh=mesh
			var material := StandardMaterial3D.new()
			material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			material.no_depth_test=true
			plot_overlay.material_override=material
			plot_overlay.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			world.add_child(plot_overlay)
			plot_caption=_label3d("",Vector3(strip.position.x+strip.end.x,1.7,strip.position.y*2-1),Color.WHITE)
			plot_caption.no_depth_test=true
			world.add_child(plot_caption)
	if index<0:return
	var boundary: String=model.expansion_boundary_error(index)
	if not boundary.is_empty():
		plot_overlay.material_override.albedo_color=Color("c28c78")
		plot_caption.modulate=Color("c28c78")
		plot_caption.text="NOT FOR SALE\n"+boundary
		return
	var cost: int=model.expansion_cost(index)
	var error: String=model.expansion_error(index)
	var tint := Color("d9c182") if error.is_empty() else Color("c28c78")
	plot_overlay.material_override.albedo_color=tint
	plot_caption.modulate=tint
	var acquisition: bool=not model.business_owned and strip.intersects(Model.BUSINESS_LAND)
	plot_caption.text="%d × %d NEW TILES%s\n%d coins · %s" % [strip.size.x,strip.size.y," + BUSINESS" if acquisition else "",cost,"Click to unlock" if error.is_empty() else error]
