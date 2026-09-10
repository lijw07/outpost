extends Node2D
## Small top-down pixel puppet. Feet follow distance travelled; aim is independent.

const ZOMBIE_ATTACK_CYCLE := 0.85
const ZOMBIE_CONTACT := 0.42
var attack_clock := 0.0
var attack_hit := false
var attack_target: Node2D

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
var spawn_position := Vector2.ZERO
var render_offset := Vector2.ZERO
var head_socket := Vector2(0,-61)
var torso_socket := Vector2(0,-36)
var head_width := 26.0
var pose_shift := Vector2.ZERO
var combat_target: Node2D
var target_clock := 0.0
var patrol_point := Vector2.INF
var patrol_index := 0
var patrol_pause := 0.0
var facing := 0
var wardrobe: Node2D
var hand_layer: Node2D
var loadout_slot := 0
var melee_clock := 0.0
var melee_hit := false
var melee_target: Node2D
var melee_weapon: Dictionary = {}
var firearm: Dictionary = {}
var rounds := 0
var reserve_ammo := 0
var reload_clock := 0.0
var ammo_pickup_clock := 0.0
var pose_clock := 0.0
var phase := 0.0
var armed_phase := 0.0
var shot_target: Node2D
var moving_recoil := Vector2.ZERO
var action_phase := 0.0
var cooldown := 0.0
var work := 0.0
var carrying := 0
var flash := 0.0
var shot_age := 10.0
var hurt := 0.0
var stun_time := 0.0
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
	for clip_name: String in (["zombie","death"] if undead else ["survivor","carry","build","shoot","move_shoot"]):
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
		clips[clip_name] = {"frames":textures,"pivots":anchors,"muzzles":muzzles,"sockets":data.frames,"scale":74.0/float(data.height)}
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

func equip(slot: int, outfit_index: int, weapon_index: int) -> void:
	loadout_slot = slot
	wardrobe = load("res://scripts/ui/menu_demo_wardrobe.gd").new()
	wardrobe.setup(outfit_index,weapon_index)
	add_child(wardrobe)
	wardrobe.held.reparent(self)
	hand_layer = Node2D.new()
	add_child(hand_layer)
	hand_layer.draw.connect(_draw_hands)
	melee_weapon = wardrobe.weapon
	firearm = wardrobe.firearm
	reset_ammo()
	wardrobe.dress(body.material)
	_update_body()

func reset_ammo() -> void:
	rounds = int(firearm.get("capacity",30))
	reserve_ammo = rounds*3

func animate(delta: float, displacement := Vector2.ZERO) -> void:
	pose_clock += delta
	velocity = displacement / maxf(delta, 0.001)
	if displacement.length_squared() < 0.001:
		move_velocity = Vector2.ZERO
	detour_time = maxf(0,detour_time-delta)
	target_clock = maxf(0,target_clock-delta)
	phase += displacement.length() / (48.0 if team else 60.0)
	if action == "shoot":
		armed_phase += displacement.length()/60.0*(-1.0 if displacement.dot(aim)<0.0 else 1.0)
	else:
		armed_phase = phase
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
	stun_time = maxf(0.0,stun_time-delta)
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
	if wardrobe != null:
		wardrobe.update_pose(self)
	if hand_layer != null:
		hand_layer.queue_redraw()
	queue_redraw()

func muzzle_offset() -> Vector2:
	if uses_sprite_gun():
		var texture: Texture2D = wardrobe.held.texture
		var scale_factor: float = weapon_scale()/texture.get_width()
		var barrel := Vector2(texture.get_width()*0.67,texture.get_height()*(-0.32 if aim.x >= 0 else 0.32))
		return render_offset+weapon_grip()+barrel.rotated(weapon_direction().angle())*scale_factor
	if current_clip in ["shoot","move_shoot"]:
		var clip: Dictionary=clips[current_clip]
		var muzzle: Vector2=(clip.muzzles[current_frame]-clip.pivots[current_frame])*float(clip.scale)
		var height: float=clip.pivots[current_frame].y*float(clip.scale)
		return body.position+muzzle+moving_recoil*clampf(-muzzle.y/height,0.0,1.0)
	return Vector2(0, -34) + aim.normalized() * 42.0

func uses_sprite_gun() -> bool:
	return wardrobe != null and not firearm.is_empty()

func weapon_kind() -> String:
	if wardrobe == null or health <= 0 or action in ["build","gather"] or carrying > 0:
		return ""
	return "melee" if action == "melee" or loadout_slot == 0 else "firearm"

func melee_progress() -> float:
	return clampf(melee_clock/maxf(float(melee_weapon.get("cycle",1)),0.01),0,1)

func resting_weapon_direction() -> Vector2:
	return Vector2.UP

func melee_engagement() -> float:
	if action != "melee":
		return 0.0
	var progress := melee_progress()
	return smoothstep(0,0.2,progress)*(1.0-smoothstep(0.58,1,progress))

func swing_angle() -> float:
	return angle_difference(aim.angle(),weapon_direction().angle())

func weapon_sway() -> Vector2:
	if action == "melee":
		return Vector2.ZERO
	return Vector2(sin(phase*TAU)*0.8,cos(phase*TAU*2)*0.6) if velocity.length_squared() > 1 else Vector2(0,sin(pose_clock*2.2+loadout_slot)*0.45)

func weapon_grip() -> Vector2:
	var torso := torso_socket+pose_shift*0.55
	if weapon_kind() == "melee":
		var side := 1.0 if facing in [0,1] else -1.0
		var rest := torso+Vector2(side*19,7)+weapon_sway()
		if action != "melee":
			return rest
		var progress := melee_progress()
		var raised := torso+Vector2(side*18,-16)
		var contact := torso+Vector2(aim.x*24,16+aim.y*7)
		if progress < 0.22:
			return rest.lerp(raised,smoothstep(0,0.22,progress))
		if progress < 0.42:
			return raised.lerp(contact,smoothstep(0.22,0.42,progress))
		return contact.lerp(rest,smoothstep(0.52,1,progress))
	var direction := weapon_direction()
	var grip := torso+Vector2(direction.x,direction.y*0.55)*14+moving_recoil*0.5+weapon_sway()
	if action not in ["shoot","reload"]:
		grip.y += 5
	return grip

func support_grip() -> Vector2:
	var grip := weapon_grip()
	if weapon_kind() == "melee":
		var side := 1.0 if facing in [0,1] else -1.0
		var free_hand := torso_socket+Vector2(-side*12,13)+weapon_sway()
		# The free hand stays relaxed; longer weapons use both hands for the strike.
		return free_hand.lerp(grip+weapon_direction()*4,melee_engagement()) if float(melee_weapon.length) >= 36 else free_hand
	return grip+weapon_direction()*(2 if firearm.get("id","") == "pistol" else 12)

func weapon_direction() -> Vector2:
	if weapon_kind() != "melee":
		return aim
	var rest := resting_weapon_direction()
	if action != "melee":
		return rest
	var progress := melee_progress()
	# An overhead arc starts vertical, then descends toward the target.
	# Side views follow their facing; front/back views keep a readable diagonal.
	var side := 1.0 if facing in [0,1] else -1.0
	var contact_angle := Vector2(side*maxf(absf(aim.x),0.35),0.7).angle()
	if side < 0:
		contact_angle -= TAU
	var strike := smoothstep(0.22,0.42,progress)*(1-smoothstep(0.52,1,progress))
	return Vector2.from_angle(lerpf(-PI/2,contact_angle,strike))

func weapon_scale() -> float:
	if weapon_kind() == "melee":
		# Upright weapons extend in elevation, so do not flatten them like a gun.
		return float(melee_weapon.length)
	var direction := weapon_direction()
	return float(firearm.length)*Vector2(direction.x,direction.y*0.55).length()

func zombie_attack_progress() -> float:
	return clampf(attack_clock/ZOMBIE_ATTACK_CYCLE,0,1)

func zombie_reach() -> float:
	var progress := zombie_attack_progress()
	return smoothstep(0.24,ZOMBIE_CONTACT,progress)*(1-smoothstep(0.5,1,progress))

func zombie_hand() -> Vector2:
	var side := 1.0 if facing in [0,1] else -1.0
	var raised := Vector2(side*14,-50)
	var contact := Vector2(aim.x*38,-34+aim.y*22)
	var rest := Vector2(side*17,-30)
	var progress := zombie_attack_progress()
	if progress < 0.24:
		return rest.lerp(raised,smoothstep(0,0.24,progress))
	if progress < ZOMBIE_CONTACT:
		return raised.lerp(contact,smoothstep(0.24,ZOMBIE_CONTACT,progress))
	return contact.lerp(rest,smoothstep(0.5,1,progress))

func melee_ready() -> bool:
	return weapon_kind() == "melee"

func visible_weapon_hands() -> bool:
	return facing != 2 or (weapon_kind() == "melee" and action != "melee")

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
			current_clip = "survivor" if uses_sprite_gun() else ("move_shoot" if moving else "shoot")
		elif action == "build":
			current_clip = "build"
		elif carrying > 0 and action != "shoot":
			current_clip = "carry"
	var pose := int(phase*4)%4 if moving else 1
	if action == "build":
		pose = clampi(int(build_clock/0.2),0,3)
	elif action == "shoot":
		if moving:
			pose=posmod(int(floor(armed_phase*4.0)),4)
		elif not uses_sprite_gun():
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
	pose_shift = Vector2.ZERO
	if action == "melee":
		var progress := melee_progress()
		var strike := smoothstep(0.18,0.4,progress)*(1-smoothstep(0.48,0.9,progress))
		pose_shift = aim*(strike*5-2*sin(progress*PI))*melee_engagement()
	if wardrobe != null:
		var sockets: Dictionary = clip.sockets[current_frame]
		var head: Array = sockets.get("head",[pivot.x,pivot.y-61/float(clip.scale)])
		var torso: Array = sockets.get("torso",[pivot.x,pivot.y-36/float(clip.scale)])
		head_socket = (Vector2(head[0],head[1])-clip.pivots[current_frame])*float(clip.scale)
		torso_socket = (Vector2(torso[0],torso[1])-clip.pivots[current_frame])*float(clip.scale)
		if body.flip_h:
			head_socket.x *= -1
			torso_socket.x *= -1
		head_width = float(sockets.get("head_width",26/float(clip.scale)))*float(clip.scale)
		var atlas := body.texture as AtlasTexture
		body.material.set_shader_parameter("frame_region",Vector4(atlas.region.position.x/atlas.atlas.get_width(),atlas.region.position.y/atlas.atlas.get_height(),atlas.region.size.x/atlas.atlas.get_width(),atlas.region.size.y/atlas.atlas.get_height()))
		body.material.set_shader_parameter("frame_pivot",clip.pivots[current_frame]/atlas.get_size())
		body.material.set_shader_parameter("frame_size",atlas.get_size()*float(clip.scale))
		body.material.set_shader_parameter("frame_flipped",body.flip_h)
		body.material.set_shader_parameter("torso_socket",torso_socket)
		body.material.set_shader_parameter("head_socket",head_socket)
		body.material.set_shader_parameter("head_width",head_width)
	if team == 1:
		var atlas := body.texture as AtlasTexture
		body.material.set_shader_parameter("zombie_attack",action == "attack" and health > 0)
		body.material.set_shader_parameter("frame_region",Vector4(atlas.region.position.x/atlas.atlas.get_width(),atlas.region.position.y/atlas.atlas.get_height(),atlas.region.size.x/atlas.atlas.get_width(),atlas.region.size.y/atlas.atlas.get_height()))
		body.material.set_shader_parameter("frame_pivot",pivot/atlas.get_size())
		body.material.set_shader_parameter("frame_size",atlas.get_size()*float(clip.scale))
		body.material.set_shader_parameter("facing_direction",facing)
		if action == "attack":
			pose_shift = Vector2(aim.x*5,aim.y*3)*zombie_reach()
	var shot_direction: Vector2=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][direction]
	var recoil_strength := 4.0 if firearm.get("id","") in ["sniper","shotgun","rocket_launcher"] else 2.4
	moving_recoil=-(aim if uses_sprite_gun() else shot_direction)*recoil_strength*exp(-shot_age*24.0) if action=="shoot" else Vector2.ZERO
	body.material.set_shader_parameter("sprite_recoil_offset",(moving_recoil+pose_shift)/float(clip.scale))
	body.material.set_shader_parameter("sprite_recoil_height",maxf(pivot.y,1.0))
	body.position = render_offset
	shadow.position = render_offset
	shadow.visible = health > 0 or death_age < 0.35
	body.rotation = 0
	body.modulate = tint.lerp(Color(1,0.58,0.5),minf(hurt,0.4))
	if health <= 0:
		body.modulate.a = 1.0-smoothstep(3.0,4.0,death_age) if team else 1.0-smoothstep(0.1,0.6,death_age)
	# The rifle is part of the drawn pose; only muzzle flashes draw over the body.
	body.show_behind_parent = true
	if wardrobe != null:
		wardrobe.update_pose(self)

func _draw() -> void:
	draw_set_transform(render_offset,0,Vector2(2,2))
	if health <= 0:
		return
	var skin := Color("c5a17b") if team == 0 else Color("929a74")
	var sleeve := Color(wardrobe.outfit.jacket) if wardrobe != null else Color("8b714b")
	if wardrobe != null and weapon_kind() != "" and visible_weapon_hands():
		var grip := weapon_grip()*0.5
		var shoulder := (torso_socket+pose_shift*0.55)*0.5+Vector2(0,-3)
		var support := support_grip()*0.5
		var hand_side := 1.0 if facing in [0,1] else -1.0
		var arm_pairs: Array = [[shoulder+Vector2(hand_side*6,0),grip],[shoulder+Vector2(-hand_side*6,0),support]]
		if facing in [1,3]:
			arm_pairs = [[shoulder+Vector2(-2 if facing == 1 else 2,1),grip]]
		for pair in arm_pairs:
			var elbow: Vector2 = pair[0]+Vector2(0,6)
			elbow = elbow.lerp(pair[1],0.25)
			_stroke(pair[0],elbow,4,INK)
			_stroke(elbow,pair[1],3,INK)
			_stroke(pair[0],elbow,2,sleeve)
			_stroke(elbow,pair[1],1,sleeve)
			_stroke(pair[0]+Vector2(0,-1),elbow+Vector2(0,-1),1,sleeve.lightened(0.18))
	if action == "shoot" and flash > 0:
		var tip := (muzzle_offset()-render_offset)*0.5
		var shot_direction: Vector2 = aim if uses_sprite_gun() else [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][int(current_frame/4.0)]
		_stroke(tip,tip+shot_direction*4,3,Color("efb94d"))
		_stroke(tip,tip+shot_direction*3,1,Color("fff1a3"))
	elif action == "build" and carrying > 0:
		# Materials are set beside the worker while both hands operate the hammer.
		_box(10,-3,14,5,INK)
		for row in mini(carrying,3):
			_box(11,-3+row*2,12,1,Color("ab8150"))
	elif action == "attack" and team == 1:
		var side := 1.0 if facing in [0,1] else -1.0
		var shoulder := Vector2(side*6,-21)+pose_shift*0.25
		var hand := zombie_hand()*0.5
		var elbow := shoulder.lerp(hand,0.55)+Vector2(-side*2,2)
		_stroke(shoulder,elbow,5,INK)
		_stroke(shoulder,elbow,3,Color("5d6350"))
		_stroke(elbow,hand,4,INK)
		_stroke(elbow,hand,2,skin)
		_box(hand.x-2,hand.y-2,4,4,INK)
		_box(hand.x-1,hand.y-1,2,2,skin.lightened(0.12))
	if hurt > 0:
		_box(-10,-42,20,2,INK)
		_box(-10,-42,floorf(20*health/(85.0 if team else 150.0)),2,Color("ab634a") if team else Color("97b15c"))

func _draw_hands() -> void:
	if health <= 0 or wardrobe == null or weapon_kind() == "" or not visible_weapon_hands():
		return
	var grip := render_offset+weapon_grip()
	var support := render_offset+support_grip()
	for point: Vector2 in [grip,support]:
		hand_layer.draw_rect(Rect2((point-Vector2(2,2)).snapped(Vector2(2,2)),Vector2(4,4)),INK)
		hand_layer.draw_rect(Rect2(point.snapped(Vector2(2,2)),Vector2(2,2)),Color("c5a17b"))
