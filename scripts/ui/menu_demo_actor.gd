extends Node2D
## Small top-down pixel puppet. Feet follow distance travelled; aim is independent.

const INK := Color("14211f")
var team := 0
var role := 0
var health := 100.0
var action := "idle"
var aim := Vector2.DOWN
var velocity := Vector2.ZERO
var move_velocity := Vector2.ZERO
var blocked_time := 0.0
var detour_time := 0.0
var previous_position := Vector2.ZERO
var render_offset := Vector2.ZERO
var facing := 0
var phase := 0.0
var action_phase := 0.0
var cooldown := 0.0
var work := 0.0
var carrying := 0
var flash := 0.0
var shot_age := 10.0
var hurt := 0.0
var death_age := 0.0
var home := Vector2.ZERO
var supply_lane := 0
var avoidance := Vector2.ZERO
var avoidance_time := 0.0
var work_position := Vector2.INF
var target: Node2D
var route := PackedVector2Array()
var route_target := Vector2.INF
var route_clock := 0.0
var tint := Color.WHITE
var clips: Dictionary = {}
var current_clip := "survivor"
var current_frame := 0
var build_clock := 0.0
var build_struck := false
var body: Sprite2D
var shadow: Polygon2D
static var _frame_data: Dictionary = {}

func setup(undead: bool, job: int) -> void:
	team = 1 if undead else 0
	role = job
	health = 85.0 if undead else 150.0
	if _frame_data.is_empty():
		_frame_data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/menu/characters/frames.json"))
	for clip_name: String in (["zombie","death"] if undead else ["survivor","carry","build","shoot"]):
		var data: Dictionary = _frame_data[clip_name]
		var atlas: Texture2D = load("res://assets/menu/characters/"+data.path)
		var textures: Array[AtlasTexture] = []
		var anchors: Array[Vector2] = []
		var muzzles: Array[Vector2] = []
		for entry: Dictionary in data.frames:
			var frame := AtlasTexture.new()
			frame.atlas = atlas
			frame.region = Rect2(entry.region[0],entry.region[1],entry.region[2],entry.region[3])
			textures.append(frame)
			anchors.append(Vector2(entry.pivot[0],entry.pivot[1]))
			if entry.has("muzzle"):muzzles.append(Vector2(entry.muzzle[0],entry.muzzle[1]))
		clips[clip_name] = {"frames":textures,"pivots":anchors,"muzzles":muzzles,"scale":74.0/float(data.height)}
	shadow = Polygon2D.new()
	shadow.polygon = PackedVector2Array([Vector2(-16,-2),Vector2(-10,-6),Vector2(10,-6),Vector2(16,-2),Vector2(12,4),Vector2(-12,4)])
	shadow.color = Color(0.04,0.07,0.05,0.38)
	shadow.show_behind_parent = true
	add_child(shadow)
	body = Sprite2D.new()
	body.centered = false
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var palette := ShaderMaterial.new()
	palette.shader = preload("res://assets/shaders/menu_actor_palette.gdshader")
	body.material = palette
	add_child(body)
	_update_body()

func animate(delta: float, displacement := Vector2.ZERO) -> void:
	velocity = displacement / maxf(delta, 0.001)
	if displacement.length_squared() < 0.001:
		move_velocity = Vector2.ZERO
	detour_time = maxf(0,detour_time-delta)
	phase += displacement.length() / (48.0 if team else 60.0)
	if action in ["build", "gather", "attack"]:
		action_phase += delta * 8.0
	else:
		action_phase = 0.0
	if action != "build":
		build_clock = 0.0
		build_struck = false
	if action == "run" and displacement.length_squared() < 0.01:
		action = "idle"
	cooldown = maxf(0.0, cooldown - delta)
	avoidance_time = maxf(0.0, avoidance_time-delta)
	route_clock = maxf(0.0, route_clock - delta)
	flash = maxf(0.0, flash - delta)
	shot_age += delta
	hurt = maxf(0.0, hurt - delta)
	if health <= 0.0:
		death_age += delta
	_update_body()
	render_interpolated(1.0)
	queue_redraw()

func render_interpolated(weight: float) -> void:
	# Interpolate the drawing between simulation ticks, never the collision body.
	var point := previous_position.lerp(position,weight)
	render_offset = point.snapped(Vector2(2,2))-position
	body.position = render_offset
	shadow.position = render_offset
	queue_redraw()

func muzzle_offset() -> Vector2:
	if current_clip == "shoot":
		var clip: Dictionary=clips[current_clip]
		return body.position+(clip.muzzles[current_frame]-clip.pivots[current_frame])*float(clip.scale)
	return Vector2(0, -34) + aim.normalized() * 42.0

func begin_shot() -> void:
	shot_age=0.0
	flash=0.065
	_update_body()

func _box(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(Vector2(x,y).round(), Vector2(w,h)), color)

func _stroke(from: Vector2, to: Vector2, width: int, color: Color) -> void:
	var count := maxi(1, ceili(from.distance_to(to)))
	for index in count + 1:
		var point := from.lerp(to, float(index) / count).round()
		_box(point.x - width / 2.0, point.y - width / 2.0, width, width, color)

func _update_body() -> void:
	if body == null:
		return
	# Hysteresis prevents left/front flicker on almost-diagonal routes.
	var horizontal := absf(aim.x) > absf(aim.y)*(0.8 if facing in [1,3] else 1.25)
	facing = (1 if aim.x > 0 else 3) if horizontal else (2 if aim.y < 0 else 0)
	var direction := facing
	var moving := velocity.length_squared() > 1
	current_clip = "zombie" if team else "survivor"
	if team == 0:
		if action == "shoot":
			current_clip = "shoot"
		elif action == "build":
			current_clip = "build"
		elif carrying > 0 and action != "shoot":
			current_clip = "carry"
	var pose := int(phase*4)%4 if moving else 1
	if action == "build":
		pose = clampi(int(build_clock/0.2),0,3)
	elif action == "shoot":
		pose=1 if shot_age<0.065 else 2 if shot_age<0.15 else 3 if shot_age<0.25 else 0
	if health <= 0 and team == 1:
		current_clip = "death"
		pose = clampi(int(death_age/0.16),0,3)
	var clip: Dictionary = clips[current_clip]
	body.flip_h = current_clip in ["survivor","carry"] and direction in [0,2] and pose == 2
	if body.flip_h:
		pose = 0
	current_frame = direction*4+pose
	body.texture = clip.frames[current_frame]
	body.material.set_shader_parameter("key_neutral_background",current_clip=="shoot")
	var pivot: Vector2 = clip.pivots[current_frame]
	if body.flip_h:
		pivot.x = body.texture.get_width()-pivot.x
	body.offset = -pivot
	body.scale = Vector2.ONE*float(clip.scale)
	body.position = render_offset
	shadow.position = render_offset
	shadow.visible = health > 0 or death_age < 0.35
	body.rotation = 0
	body.modulate = tint.lerp(Color(1,0.58,0.5),minf(hurt,0.4))
	if health <= 0:
		body.modulate.a = 1.0-smoothstep(3.0,4.0,death_age) if team else 1.0-smoothstep(0.1,0.6,death_age)
	# The rifle is part of the drawn pose; only muzzle flashes draw over the body.
	body.show_behind_parent = true

func _draw() -> void:
	draw_set_transform(render_offset,0,Vector2(2,2))
	if health <= 0:
		return
	var skin := Color("c5a17b") if team == 0 else Color("929a74")
	if action == "shoot":
		if flash > 0:
			var tip := (muzzle_offset()-body.position)*0.5
			var shot_direction: Vector2=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][int(current_frame/4.0)]
			_stroke(tip,tip+shot_direction*4,3,Color("efb94d"))
			_stroke(tip,tip+shot_direction*3,1,Color("fff1a3"))
	elif action == "build" and carrying > 0:
		# Materials are set beside the worker while both hands operate the hammer.
		_box(10,-3,14,5,INK)
		for row in mini(carrying,3):
			_box(11,-3+row*2,12,1,Color("ab8150"))
	elif action == "attack":
		var hand := Vector2(0,-15)+aim*(12 if int(action_phase)%2 else 8)
		_stroke(Vector2(5,-20),hand,4,INK)
		_stroke(Vector2(5,-20),hand,2,skin)
	if hurt > 0:
		_box(-10,-42,20,2,INK)
		_box(-10,-42,floorf(20*health/(85.0 if team else 150.0)),2,Color("ab634a") if team else Color("97b15c"))
