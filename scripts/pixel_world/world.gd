extends Node3D
## Hybrid world: actual 3D terrain/collision/light, native-resolution sprite cards.
const Art := preload("res://scripts/pixel_world/art.gd")
const Pawn := preload("res://scripts/pixel_world/actor.gd")
const UNIT := 48.0
const DEPTH := 1.41421356237
var simulation: Node2D
var interactive := false
var camera: Camera3D
var actors: Dictionary = {}
var fences: Dictionary = {}
var harvestables: Array[Node3D] = []
var lights: Array[OmniLight3D] = []
var player: CharacterBody3D
var player_actor: Node2D
var roof: Node3D
var _materials: Dictionary = {}
var _clock := 0.0
var _chop_clock := 0.0
var _water: ShaderMaterial
var _particles: MultiMeshInstance3D
var _falling: Array[Node3D] = []
var _foliage: Array[ShaderMaterial] = []
var _collected := {"wood":0,"flowers":0,"mushrooms":0}
signal collected(kind: String, amount: int)

static func point(at: Vector2) -> Vector3:
	return Vector3(at.x/UNIT,0,at.y/UNIT*DEPTH)
static func flat(at: Vector3) -> Vector2:
	return Vector2(at.x*UNIT,at.z/DEPTH*UNIT)

func _ready() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 22.5
	camera.near = 0.1
	camera.far = 100
	add_child(camera)
	camera.position = point(Vector2(960,540))+Vector3(0,30,30)
	camera.look_at(point(Vector2(960,540)))
	camera.current = true
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("142522")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a9bbc8")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62,-24,0)
	sun.light_color = Color("e7c79a")
	sun.light_energy = 0.62
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70
	add_child(sun)
	_ground()
	_camp()
	_scenery()
	for at in [simulation._fire_point,Vector2(1270,430),Vector2(1530,460)]:
		var lamp := OmniLight3D.new()
		lamp.position = point(at)+Vector3(0,1.6,0)
		lamp.light_color = Color("ffb75c")
		lamp.light_energy = 2.0
		lamp.omni_range = 6
		lamp.shadow_enabled = true
		add_child(lamp)
		lights.append(lamp)
	_particles = MultiMeshInstance3D.new()
	var particles := MultiMesh.new()
	particles.transform_format = MultiMesh.TRANSFORM_3D
	particles.use_colors = true
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE*Art.PIXEL
	particles.mesh = cube
	particles.instance_count = 192
	particles.visible_instance_count = 0
	_particles.multimesh = particles
	var particle_material := StandardMaterial3D.new()
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.vertex_color_use_as_albedo = true
	_particles.material_override = particle_material
	add_child(_particles)
	sync(0)
	if interactive:
		player_actor = simulation.survivors[0]
		simulation.controlled_actor = player_actor
		player = actors[player_actor.get_instance_id()]
		player.controlled = true

func _material(key: String, color: Color, planks := false) -> StandardMaterial3D:
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_texture = Art.tile(color,key.hash(),planks)
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.roughness = 1
		if planks:
			var outline := ShaderMaterial.new()
			outline.shader = preload("res://assets/pixel_world/outline.gdshader")
			material.next_pass = outline
		_materials[key] = material
	return _materials[key]

func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material, collision := false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	if collision:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		shape.shape = bounds
		body.add_child(shape)
		mesh.add_child(body)
	return mesh

func _ground() -> void:
	var colors := [Color("456847"),Color("987c52"),Color("496b46"),Color("345963")]
	var groups: Array[Array] = [[],[],[],[]]
	var shores := StaticBody3D.new()
	shores.name = "ShoreCollision"
	add_child(shores)
	for y in range(-4,30):
		for x in range(-4,49):
			var center := Vector2(x*48+24,y*48+24)
			var land: bool = simulation._on_land(center,0)
			var clearing: bool = ((center-Vector2(1320,600))/Vector2(470,370)).length()<1
			var kind := 3 if not land else 1 if clearing or (simulation.variant == 1 and y in range(17,21)) else 2 if posmod(x*13+y*7,11)<2 else 0
			if not land:
				var block := CollisionShape3D.new()
				var shape := BoxShape3D.new()
				shape.size = Vector3(1,2,DEPTH)
				block.shape = shape
				block.position = Vector3(x+0.5,0.5,(y+0.5)*DEPTH)
				shores.add_child(block)
			groups[kind].append(Vector3(x+0.5,-0.08 if land else -0.20,(y+0.5)*DEPTH))
	for index in 4:
		var batch := MultiMeshInstance3D.new()
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		var tile_mesh := BoxMesh.new()
		tile_mesh.size = Vector3(1,0.16,DEPTH)
		multi.mesh = tile_mesh
		multi.instance_count = groups[index].size()
		for tile in groups[index].size():
			multi.set_instance_transform(tile,Transform3D(Basis.IDENTITY,groups[index][tile]))
		batch.multimesh = multi
		batch.material_override = _material("ground"+str(index),colors[index])
		if index == 3:
			_water = ShaderMaterial.new()
			_water.shader = preload("res://assets/pixel_world/water.gdshader")
			batch.material_override = _water
		add_child(batch)
	# Land collisions are a single slab; shores add actual blocking volumes.
	_box(self,Vector3(20,-0.26,12*DEPTH),Vector3(48,0.5,32*DEPTH),_material("soil",Color("514934")),true).hide()

func _camp() -> void:
	var wood := _material("wood",Color("946337"),true)
	var dark := _material("beams",Color("4c3827"),true)
	var roof_color: Color = [Color("5b797a"),Color("815643"),Color("675d48")][simulation.variant]
	var metal := _material("roof",roof_color,true)
	var center := point(Vector2(1300,460))
	_box(self,center+Vector3(0,0.04,0),Vector3(3.8,0.16,2.8*DEPTH),wood)
	_box(self,center+Vector3(0,0.8,-1.25*DEPTH),Vector3(3.8,1.6,0.16),wood,true)
	for side in [-1,1]:
		_box(self,center+Vector3(side*1.85,0.8,0),Vector3(0.16,1.6,2.6*DEPTH),wood,true)
		_box(self,center+Vector3(side*1.3,0.8,1.25*DEPTH),Vector3(1.1,1.6,0.16),wood,true)
		_box(self,center+Vector3(side*1.83,1.0,1.27*DEPTH),Vector3(0.20,2,0.20),dark)
	roof = Node3D.new()
	add_child(roof)
	for side in [-1,1]:
		var panel := _box(roof,center+Vector3(0,2.2,side*0.75*DEPTH),Vector3(4.3,0.15,1.65*DEPTH),metal)
		panel.rotation.x = side*0.3
	_box(roof,center+Vector3(0,2.6,0),Vector3(4.35,0.15,0.16),dark)
	_prop(5,simulation._depot,true)
	_prop(6,simulation._ammo_depot,true)
	_prop(15,simulation._supply_point,true)
	_prop(12,Vector2(1770,780) if simulation.variant != 1 else Vector2(1030,940),true)
	_prop(13,Vector2(1560,515),true)
	_prop(8,simulation._fire_point,false)

func _prop(index: int, at: Vector2, collision: bool) -> Node3D:
	var root := Node3D.new()
	root.position = point(at)
	add_child(root)
	var sprite := Art.sprite(Art.frame("props",index))
	sprite.rotation.x = -PI/4
	var height: float = sprite.texture.get_height()*Art.PIXEL
	sprite.position = Vector3(0,height*0.35355339,-height*0.35355339)
	root.add_child(sprite)
	if index in [0,1,2,8,9,10]:
		var sway := ShaderMaterial.new()
		sway.shader = preload("res://assets/pixel_world/foliage.gdshader")
		sway.set_shader_parameter("sprite_texture",sprite.texture)
		sway.set_shader_parameter("pixel_size",Vector2(1.0/sprite.texture.get_width(),1.0/sprite.texture.get_height()))
		sway.set_shader_parameter("flame",index == 8)
		sprite.material_override = sway
		_foliage.append(sway)
	root.set_meta("sprite",sprite)
	root.set_meta("kind",index)
	if collision:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.6 if index<4 else 0.95,0.8,0.65*DEPTH)
		collider.shape = shape
		collider.position.y = 0.4
		body.add_child(collider)
		root.add_child(body)
		root.set_meta("collision",body)
	if index < 4 or index in [9,11]:
		root.set_meta("resource", "wood" if index<4 else "mushrooms" if index == 11 else "flowers")
		root.set_meta("health",3 if index<4 else 1)
		harvestables.append(root)
	return root

func _scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 910+simulation.variant*19
	for index in simulation.scenery_bounds.size():
		var bounds: Rect2 = simulation.scenery_bounds[index]
		var kind: String = simulation.scenery_kinds[index]
		if kind == "camp":
			continue
		var at := Vector2(bounds.get_center().x,bounds.end.y)
		if kind == "tree":
			at.y -= 4
		var prop := _prop(4 if kind == "rock" else (2 if simulation.variant == 2 else index%2),at,true)
		if kind == "tree":
			prop.set_meta("navigation_footprint",Rect2(at-Vector2(20,14),Vector2(40,28)))
	for prop in simulation.ground_props:
		_prop(11 if rng.randf()<0.12 else 9 if rng.randf()<0.2 else 10,prop.position,false)

func _fence(source: Node2D) -> void:
	var key: int = source.get_instance_id()
	var count: int = floori(source.progress*source.section_count()) if source.health>0 else 0
	if fences.has(key) and fences[key].get_meta("count") == count:
		return
	if fences.has(key):
		fences[key].free()
	var group := Node3D.new()
	group.set_meta("count",count)
	add_child(group)
	fences[key] = group
	var bounds: Rect2 = source.collision_bounds()
	if not bounds.has_area():
		return
	var center := point(bounds.get_center())
	var dimensions := Vector3(bounds.size.x/UNIT,0.65,bounds.size.y/UNIT*DEPTH)
	var collision := StaticBody3D.new()
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	shape_node.shape = shape
	collision.position = center+Vector3(0,0.325,0)
	collision.add_child(shape_node)
	group.add_child(collision)
	var material := _material("fence",Color("a98649"),true)
	for post in count:
		var fraction := float(post)/maxi(count-1,1)
		var offset := Vector3(0,0,dimensions.z*fraction) if source.vertical else Vector3(dimensions.x*fraction,0,0)
		var base := point(bounds.position)+offset
		_box(group,base+Vector3(0,0.42,0),Vector3(0.12,0.84,0.12),material)
	for height in [0.3,0.6]:
		_box(group,center+Vector3(0,height,0),Vector3(0.07,0.10,dimensions.z) if source.vertical else Vector3(dimensions.x,0.10,0.07),material)

func sync(delta: float) -> void:
	_clock += delta
	_water.set_shader_parameter("phase",_clock*2)
	for index in _foliage.size():
		_foliage[index].set_shader_parameter("phase",_clock*2+index*0.71)
	var active := {}
	for source in simulation.survivors+simulation.zombies:
		var key: int = source.get_instance_id()
		active[key] = true
		if not actors.has(key):
			var pawn := Pawn.new()
			pawn.source_actor = source
			pawn.outfit = (4 if simulation.variant == 2 and source.loadout_slot == 1 else 5 if simulation.variant == 1 and source.loadout_slot == 0 else source.loadout_slot) if not source.team else 0
			add_child(pawn)
			actors[key] = pawn
		var actor: CharacterBody3D = actors[key]
		if actor != player:
			actor.position = point((source.position+source.render_offset).snapped(Vector2(3,3)))
		actor.sync_pose()
	for key: int in actors.keys():
		if not active.has(key):
			actors[key].queue_free()
			actors.erase(key)
	for wall in simulation.structures:
		_fence(wall)
	for lamp in lights:
		lamp.light_energy = 1.8+sin(_clock*5.2+lamp.position.x)*0.15
	for prop in _falling.duplicate():
		var age: float = prop.get_meta("fall_age",0.0)+delta
		prop.set_meta("fall_age",age)
		var sprite: Sprite3D = prop.get_meta("sprite")
		sprite.rotation.z = -smoothstep(0,0.65,age)*PI/2
		if age >= 0.65:
			sprite.material_override = null
			sprite.texture = Art.frame("props",15)
			sprite.rotation.z = 0
			sprite.position = Vector3(0,0.25,-0.25)
			prop.set_meta("settled",true)
			_falling.erase(prop)
	if interactive and is_instance_valid(player):
		roof.visible = not Rect2(1190,370,220,170).has_point(flat(player.position))
	var count := 0
	for bullet: Dictionary in simulation.bullets:
		var direction: Vector2 = bullet.velocity.normalized()
		var particle_basis := Basis(Vector3.UP,-direction.angle()).scaled(Vector3(3,1,1))
		count = _particle(count,point(bullet.point)+Vector3(0,0.2,0),particle_basis,Color("ffd879"))
	for effect: Dictionary in simulation.effects:
		count = _particle(count,point(effect.point)+Vector3(0,0.3,0),Basis.IDENTITY,effect.color)
	for field: Dictionary in simulation.fields:
		var smoke: bool = field.kind == "smoke"
		var color := Color("65716c") if smoke else Color("edba68") if field.kind == "blast" else Color("e76b47") if field.kind == "flare" else Color("fff0c3")
		for particle in (12 if smoke else 7):
			var angle := particle*TAU/12
			var radius := 0.3+0.2*sin(_clock*2+particle)
			var at := point(field.point)+Vector3(cos(angle)*radius,0.3+particle*0.06,sin(angle)*radius)
			count = _particle(count,at,Basis.IDENTITY.scaled(Vector3.ONE*(5 if smoke else 2)),color)
	_particles.multimesh.visible_instance_count = count

func _particle(index: int, at: Vector3, particle_basis: Basis, color: Color) -> int:
	if index >= _particles.multimesh.instance_count:
		return index
	_particles.multimesh.set_instance_transform(index,Transform3D(particle_basis,at))
	_particles.multimesh.set_instance_color(index,color)
	return index+1

func move_player(direction: Vector2, delta: float, cursor: Vector2) -> void:
	if not is_instance_valid(player):
		return
	if player_actor.health <= 0:
		player_actor.health = 100
		player_actor.death_age = 0
		player.position = point(Vector2(1250,600))
	var before := player.position
	var previous_stride := int(player_actor.phase*2)
	_chop_clock = maxf(0,_chop_clock-delta)
	player.velocity = Vector3(direction.x*4.5,-3,direction.y*4.5*DEPTH)
	player.move_and_slide()
	player_actor.position = flat(player.position)
	player_actor.previous_position = player_actor.position
	player_actor.aim = direction if direction.length_squared()>0.01 else (cursor-player_actor.position).normalized()
	if player_actor.aim.length_squared()<0.1:
		player_actor.aim = Vector2.DOWN
	player_actor.action = "run" if direction.length_squared()>0 else "idle"
	if Input.is_action_pressed("attack") or player_actor.melee_clock>0:
		var enemy: Node2D = simulation._nearest(player_actor.position,simulation.zombies,float(player_actor.melee_weapon.reach))
		if enemy != null and simulation._clear_segment(player_actor.position,enemy.position):
			simulation._melee(player_actor,enemy,delta)
		else:
			if player_actor.melee_clock == 0:
				simulation.audio.emit_sound("swing",player_actor.position)
			player_actor.action = "melee"
			player_actor.melee_clock += delta
			if player_actor.melee_clock >= float(player_actor.melee_weapon.cycle):
				player_actor.melee_clock = 0
	if _chop_clock > 0:
		player_actor.action = "build"
	player_actor.animate(delta,flat(player.position)-flat(before))
	if int(player_actor.phase*2) != previous_stride:
		simulation.audio.emit_sound("footstep",player_actor.position)
	player.sync_pose()
	var half_view := Vector2(get_viewport().size)*1.5
	var focus := flat(player.position).clamp(half_view,Vector2(2112,1200)-half_view)
	camera.position = point(focus.snapped(Vector2(3,3)))+Vector3(0,24,24)
	simulation.spawn_exclusion = Rect2(focus-half_view,half_view*2).grow(96)

func cursor_world(screen: Vector2) -> Vector2:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var hit: Variant = Plane(Vector3.UP,0).intersects_ray(origin,direction)
	return flat(hit) if hit != null else Vector2.ZERO

func interact(chop := false) -> bool:
	if not is_instance_valid(player):
		return false
	var nearest: Node3D
	var distance := 1.8
	for prop in harvestables:
		if not is_instance_valid(prop) or not prop.visible:
			continue
		var wood: bool = prop.get_meta("resource") == "wood"
		var settled: bool = prop.get_meta("settled",false)
		if chop != (wood and not settled) or _falling.has(prop):
			continue
		var reach := player.position.distance_to(prop.position)
		if reach < distance:
			nearest = prop
			distance = reach
	if nearest == null:
		return false
	if chop:
		_chop_clock = 0.45
		player_actor.aim = (flat(nearest.position)-player_actor.position).normalized()
		nearest.set_meta("health",nearest.get_meta("health")-1)
		simulation.audio.emit_sound("timber",flat(nearest.position))
		if nearest.get_meta("health") <= 0:
			_falling.append(nearest)
			if nearest.has_meta("navigation_footprint"):
				simulation._footprints.erase(nearest.get_meta("navigation_footprint"))
				simulation._navigation_dirty = true
			if nearest.has_meta("collision"):
				nearest.get_meta("collision").queue_free()
	else:
		var kind: String = nearest.get_meta("resource")
		var amount := 3 if kind == "wood" else 1
		_collected[kind] += amount
		collected.emit(kind,amount)
		nearest.visible = false
	return true
