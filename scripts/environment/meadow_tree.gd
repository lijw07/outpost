extends Node2D
## Real 3D rigid-body dynamics projected into the 2D meadow.
signal hit_received(remaining_hits: int)
signal impact
signal wood_collected(amount: int)
const PACK := "res://assets/environment/meadow/trees/"
const PPM := 64.0
@export_enum("oak","birch","young_oak","deadwood") var species := "oak"
@export_range(1,10) var hits_to_fell := 3
@export_range(1,20) var wood_yield := 2
var remaining_hits := 3
var state := "standing"
var fall_direction := 1.0
var impact_count := 0
var _info: Dictionary
var _elapsed := 0.0
var _clock := 0.0
var _hit_bend := 0.0
var _hit_velocity := 0.0
var _cooldown := 0.0
var _fall_art: Sprite2D
var _fall_center := Vector2.ZERO
var _landing_time := 0.0
var _log_collected := false
var sticks: Array[Dictionary] = []
var _viewport: SubViewport
var _world: Node3D
var _ground: StaticBody3D
var _body: RigidBody3D
var _joint: PinJoint3D
var _puffs: Array[Dictionary] = []
var _material: ShaderMaterial
@onready var standing: Sprite2D = $Standing
@onready var stump: Sprite2D = $Stump
@onready var foliage: Sprite2D = $Foliage
@onready var log_sprite: Sprite2D = $Log
@onready var effects: Node2D = $Effects

func _ready() -> void:
	_info = JSON.parse_string(FileAccess.get_file_as_string(PACK+"catalog.json"))["species"][species]
	remaining_hits = hits_to_fell
	add_to_group("meadow_trees")
	_material = ShaderMaterial.new()
	_material.shader = preload("res://assets/shaders/meadow_foliage.gdshader")
	_material.set_shader_parameter("rest_texture",standing.texture)
	_material.set_shader_parameter("sprite_size",standing.texture.get_size())
	_material.set_shader_parameter("sprite_origin",standing.offset)
	standing.material = _material

func hit(from_world: Vector2, damage := 1) -> bool:
	if state != "standing" or damage <= 0 or _cooldown > 0.0: return false
	_cooldown = 0.18
	remaining_hits = maxi(0,remaining_hits-damage)
	fall_direction = 1.0 if from_world.x <= global_position.x else -1.0
	# Add momentum away from the axe without snapping the current bend.
	_hit_velocity = clampf(_hit_velocity+fall_direction*140.0,-180.0,180.0)
	hit_received.emit(remaining_hits)
	if remaining_hits == 0:
		state = "cutting"
		_elapsed = 0.0
	return true

func _process(delta: float) -> void:
	_clock += delta
	# Exact damped spring, evaluated every rendered frame: one bend and a soft return.
	var frequency := sqrt(51.0)
	var decay := exp(-7.0*delta)
	var cosine := cos(frequency*delta)
	var sine := sin(frequency*delta)
	var previous := _hit_bend
	_hit_bend = decay*(previous*cosine+(_hit_velocity+7.0*previous)/frequency*sine)
	_hit_velocity = decay*(_hit_velocity*cosine-(7.0*_hit_velocity+100.0*previous)/frequency*sine)
	if standing.visible:
		var wind := sin(_clock*1.8+position.x*.013)*4.0 + sin(_clock*3.1+position.y*.01)
		_material.set_shader_parameter("bend",wind+_hit_bend)
	_update_dust(delta)

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0,_cooldown-delta)
	if state == "cutting":
		_elapsed += delta
		if _elapsed >= 0.14: _start_fall()
	elif state == "falling":
		_sync(_body,_fall_art)
	elif state == "landing":
		_landing_time += delta
		if _landing_time >= 0.12: _spawn_landed_wood()
	elif state == "fallen":
		if not _log_collected: _sync(_body,log_sprite)
		for stick in sticks:
			if not stick["collected"]:
				_sync(stick["body"],stick["sprite"])
				stick["sprite"].rotation += PI/2.0

func _make_world() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "TreePhysics"
	_viewport.size = Vector2i(2,2)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	_ground = StaticBody3D.new()
	_ground.name = "Ground"
	var ground_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20,0.2,20)
	ground_shape.shape = box
	_ground.add_child(ground_shape)
	_ground.position.y = -0.1
	_world.add_child(_ground)

func _rigid(length: float, radius: float, mass_value: float) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = mass_value
	body.continuous_cd = true
	body.axis_lock_angular_x = true
	body.axis_lock_angular_y = true
	body.linear_damp = 0.5
	body.angular_damp = 1.0
	var material_value := PhysicsMaterial.new()
	material_value.friction = 0.9
	material_value.bounce = 0.2
	body.physics_material_override = material_value
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.height = length
	cylinder.radius = radius
	shape.shape = cylinder
	body.add_child(shape)
	return body

func _start_fall() -> void:
	state = "falling"
	_make_world()
	standing.hide()
	stump.show()
	# Crop only below the cut: the same intact trunk, branches and leaves fall together.
	_fall_art = Sprite2D.new()
	_fall_art.name = "FallingTree"
	var upper := AtlasTexture.new()
	upper.atlas = standing.texture
	upper.region = Rect2(0,0,standing.texture.get_width(),int(_info["split_rows"][1]))
	upper.filter_clip = true
	_fall_art.texture = upper
	_fall_art.centered = false
	var top := standing.offset.y+float(standing.texture.get_image().get_used_rect().position.y)
	var cut := Vector2(float(_info["pivot_x"]),float(_info["trunk_base_y"]))
	var height := cut.y-top
	_fall_center = Vector2(cut.x,cut.y-height*0.5)
	_fall_art.offset = standing.offset-_fall_center
	add_child(_fall_art)
	var length := height/PPM
	var radius := float(_info["cut_diameter"])*0.45/PPM
	_body = _rigid(length,radius,2.5)
	_body.name = "FallingTreeBody"
	_body.position = Vector3(_fall_center.x/PPM,-_fall_center.y/PPM,0)
	_body.axis_lock_linear_z = true
	_body.contact_monitor = true
	_body.max_contacts_reported = 8
	_body.angular_damp = 0.08
	_world.add_child(_body)
	_body.body_entered.connect(_ground_contact)
	var anchor := StaticBody3D.new()
	anchor.name = "CutAnchor"
	anchor.position = Vector3(cut.x/PPM,-cut.y/PPM,0)
	_world.add_child(anchor)
	_joint = PinJoint3D.new()
	_joint.position = anchor.position
	_world.add_child(_joint)
	_joint.node_a = _joint.get_path_to(anchor)
	_joint.node_b = _joint.get_path_to(_body)
	_body.angular_velocity.z = -fall_direction*0.55
	_sync(_body,_fall_art)

func _project(at: Vector3) -> Vector2:
	return Vector2(at.x,at.z-at.y)*PPM

func _sync(body: RigidBody3D, art: Sprite2D) -> void:
	art.position = _project(body.position)
	var axis := body.basis.y
	art.rotation = atan2(-axis.y,axis.x)+PI/2.0

func _ground_contact(other: Node) -> void:
	if state != "falling" or other != _ground: return
	state = "impact_pending"
	call_deferred("_begin_landing")

func _begin_landing() -> void:
	if state != "impact_pending": return
	impact_count += 1
	impact.emit()
	_sync(_body,_fall_art)
	_body.freeze = true
	_joint.queue_free()
	_landing_time = 0.0
	state = "landing"
	# Keep the landing visible: no dust at ground contact.

func _spawn_landed_wood() -> void:
	var landed := _body
	var rect := log_sprite.texture.get_image().get_used_rect()
	var pixel_center := Vector2(rect.position)+Vector2(rect.size)*0.5
	var original_center := log_sprite.offset+pixel_center
	var local_shift := original_center-_fall_center
	var radius := float(_info["cut_diameter"])*0.45/PPM
	_body = _rigid(float(rect.size.y)/PPM,radius,2.5)
	_body.name = "DroppedLog"
	_body.position = landed.position+landed.basis*Vector3(local_shift.x/PPM,-local_shift.y/PPM,0)
	_body.position.y = maxf(radius+0.01,_body.position.y)
	_body.basis = landed.basis
	_world.add_child(_body)
	log_sprite.offset = -pixel_center
	log_sprite.show()
	_sync(_body,log_sprite)
	# Small branches scatter along the space previously occupied by the canopy.
	var texture: Texture2D = preload("res://assets/environment/meadow/props/branch.png")
	var used := texture.get_image().get_used_rect()
	for i in range(3):
		var body := _rigid(0.42,0.055,0.18)
		body.name = "DroppedStick%d"%i
		body.position = landed.position+landed.basis.y*(float(i)-0.2)*0.36
		body.position.y = 0.14
		body.position.z = (float(i)-1.0)*0.30
		body.basis = landed.basis
		_world.add_child(body)
		body.apply_central_impulse(Vector3(fall_direction*0.025,0.025,(float(i)-1.0)*0.015))
		var art := Sprite2D.new()
		art.texture = texture
		art.centered = false
		art.offset = -(Vector2(used.position)+Vector2(used.size)*0.5)
		art.scale = Vector2.ONE*0.6
		add_child(art)
		_sync(body,art)
		art.rotation += PI/2.0
		sticks.append({"body":body,"sprite":art,"collected":false})
	_fall_art.hide()
	landed.queue_free()
	state = "fallen"

func collect_wood(from_world: Vector2, radius := 80.0) -> int:
	if state != "fallen": return 0
	var amount := 0
	if not _log_collected and _can_collect(_body,log_sprite,from_world,radius):
		_log_collected = true
		log_sprite.hide()
		_body.queue_free()
		amount += wood_yield
	for stick in sticks:
		if stick["collected"]: continue
		if _can_collect(stick["body"],stick["sprite"],from_world,radius):
			stick["collected"] = true
			stick["sprite"].hide()
			stick["body"].queue_free()
			amount += 1
	if _log_collected and sticks.all(func(s: Dictionary) -> bool: return s["collected"]): state = "collected"
	if amount > 0: wood_collected.emit(amount)
	return amount

func _can_collect(body: RigidBody3D, art: Sprite2D, from_world: Vector2, radius: float) -> bool:
	return is_instance_valid(body) and body.linear_velocity.length()<0.25 and body.angular_velocity.length()<0.5 and from_world.distance_to(art.global_position)<=radius

func _update_dust(delta: float) -> void:
	for i in range(_puffs.size()-1,-1,-1):
		var item := _puffs[i]
		item["time"] += delta
		var age: float = item["time"]
		if age >= item["duration"]:
			item["sprite"].queue_free()
			_puffs.remove_at(i)
		else:
			item["sprite"].modulate.a = 0.60*smoothstep(0.0,0.04,age)*(1.0-smoothstep(0.23,0.65,age))
