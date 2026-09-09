extends AnimatedSprite2D
## Smooth live foliage; source SpriteFrames remain available for pixel inspection.
signal harvested(kind: String, amount: int)

@export var contact_radius := 34.0
@export var smooth_motion := true
@export_range(0.0, 4.0, 0.1) var wind_strength := 3.0
@export var picked_texture: Texture2D
@export var pickup_kind := "flowers"
var picked := false
var bend := 0.0
var _velocity := 0.0
var _time := 0.0
var _phase := 0.0
var _brush_hold := 0.0
var _amplitude := 1.5
var _occupied := false
var _left := false
var _motion_material: ShaderMaterial

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animation_finished.connect(_animation_finished)
	play(&"wind")
	frame = posmod(int(global_position.x + global_position.y), 8)
	if picked_texture != null: add_to_group("meadow_pickables")
	if smooth_motion:
		var asset_name := sprite_frames.resource_path.get_file().get_basename()
		var path := "res://assets/environment/meadow/props/"+asset_name+".png"
		if not ResourceLoader.exists(path): path = "res://assets/environment/meadow/grass/"+asset_name+".png"
		var rest: Texture2D = load(path)
		_motion_material = ShaderMaterial.new()
		_motion_material.shader = preload("res://assets/shaders/meadow_foliage.gdshader")
		_motion_material.set_shader_parameter("rest_texture",rest)
		_motion_material.set_shader_parameter("sprite_size",rest.get_size())
		_motion_material.set_shader_parameter("sprite_origin",offset-rest.get_size()/2.0 if centered else offset)
		material = _motion_material
		_phase = fposmod(global_position.x*0.017 + global_position.y*0.009, TAU)
		_amplitude = 1.25 if rest.get_height() <= 64 else 1.9
		bend = _wind()
		_motion_material.set_shader_parameter("bend",bend)

func _wind() -> float:
	return wind_strength*_amplitude*(sin(_time*2.1+_phase)*0.8 + sin(_time*3.7+_phase*0.6)*0.2)

func _process(delta: float) -> void:
	var nearby: Node2D = null
	for body in get_tree().get_nodes_in_group("players"):
		if body is Node2D and global_position.distance_to(body.global_position) < contact_radius:
			nearby = body
			break
	if nearby != null and not _occupied:
		brush_from(nearby.global_position)
	elif nearby == null and _occupied:
		_occupied = false
		if not is_playing(): play(&"recover_left" if _left else &"recover")
	if _motion_material == null: return
	# Pausing an inspector freezes wind; contact poses can still settle naturally.
	if not is_playing() and animation == &"wind": return
	_time += delta
	_brush_hold = maxf(0.0,_brush_hold-delta)
	var target := _wind()
	if _occupied or _brush_hold > 0.0: target += -7.0 if _left else 7.0
	# Bounded spring substeps keep the response stable across render rates.
	var remaining := minf(delta,0.1)
	while remaining > 0.0:
		var step := minf(remaining,1.0/120.0)
		_velocity += ((target-bend)*190.0-_velocity*19.0)*step
		bend += _velocity*step
		remaining -= step
	_motion_material.set_shader_parameter("bend",bend)

func brush_from(world_position: Vector2) -> void:
	_occupied = true
	_left = world_position.x > global_position.x
	_brush_hold = 0.18
	play(&"brush_left" if _left else &"brush")

func harvest() -> bool:
	if picked or picked_texture == null: return false
	picked = true
	if _motion_material != null:
		_motion_material.set_shader_parameter("rest_texture",picked_texture)
	else:
		# A picked plant still has its original canvas and pivot in frame-only mode.
		var frames := sprite_frames.duplicate() as SpriteFrames
		for state in frames.get_animation_names():
			for i in range(frames.get_frame_count(state)):
				frames.set_frame(state,i,picked_texture)
		sprite_frames = frames
	harvested.emit(pickup_kind,1)
	return true

func _animation_finished() -> void:
	if String(animation).begins_with("brush"):
		if not _occupied: play(&"recover_left" if _left else &"recover")
	elif String(animation).begins_with("recover"):
		play(&"wind")
