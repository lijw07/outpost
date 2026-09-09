extends Node2D
## Autonomous attract-mode sandbox. No saves, gameplay autoloads, or user input.
## Resource hauling funds construction; defenses take damage; bullets resolve hits.

const Actor := preload("res://scripts/ui/menu_demo_actor.gd")
const Structure := preload("res://scripts/ui/menu_demo_structure.gd")
const OUTLINE := preload("res://assets/shaders/menu_pixel_outline.gdshader")
const Prop := preload("res://scripts/ui/menu_demo_prop.gd")
const Ground := preload("res://scripts/ui/menu_demo_ground.gd")
const Audio := preload("res://scripts/ui/menu_demo_audio.gd")
const Scatter := preload("res://scripts/ui/menu_demo_scatter.gd")
const STEP := 1.0 / 30.0
const CELL_SIZE := 16
const GRID_SIZE := Vector2i(124,70)
const CELL_CENTER := Vector2(8,8)
const MAX_SURVIVORS := 4
const SURVIVOR_ROLES := [0,0,1,2]
const MAX_ZOMBIES := 24
const MAX_BULLETS := 64
const MAX_EFFECTS := 90

var variant := 0
var elapsed := 0.0
var wave := 1
var supplies := 12
var stats := {"shots": 0, "kills": 0, "built": 0, "repaired": 0, "gathered": 0, "breaches": 0, "waves": 1}
var survivors: Array[Node2D] = []
var zombies: Array[Node2D] = []
var structures: Array[Node2D] = []
var bullets: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var scenery_bounds: Array[Rect2] = []
var scenery_kinds: Array[String] = []
var ground_props: Array[Node2D] = []
var entities: Node2D
var effects_layer: Node2D
var fire_sprite: Node2D
var audio: Node2D
var _groan_clock := 0.0
var _rng := RandomNumberGenerator.new()
var _accumulator := 0.0
var _spawn_clock := 0.0
var _replacement_clock := 0.0
var _wave_clock := 0.0
var _navigation := AStarGrid2D.new()
var _navigation_dirty := true
var _navigation_clock := 0.0
var _footprints: Array[Rect2] = []
var _fire_point := Vector2(1330, 620)
var _supply_point := Vector2(905, 845)
var _depot := Vector2(1180, 565)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.seed = 8103 + variant * 107
	var ground := Ground.new()
	ground.variant = variant
	add_child(ground)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	effects_layer = Node2D.new()
	add_child(effects_layer)
	effects_layer.draw.connect(_draw_effects)
	_build_location()
	audio = Audio.new()
	add_child(audio)
	_navigation.region = Rect2i(Vector2i.ZERO,GRID_SIZE)
	_navigation.cell_size = Vector2.ONE*CELL_SIZE
	_navigation.offset = CELL_CENTER
	_navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_navigation.update()
	_rebuild_navigation()
	var night := CanvasModulate.new()
	night.color = [Color(0.55,0.64,0.73), Color(0.61,0.66,0.72), Color(0.65,0.64,0.75)][variant]
	add_child(night)
	for point in [_fire_point,Vector2(1310,435),Vector2(1590,490),Vector2(1070,750)]:
		_add_light(point)
	for index in MAX_SURVIVORS:
		_add_survivor(SURVIVOR_ROLES[index], Vector2(1070 + index * 97, 750 + (index % 2) * 65))
	for index in 8:
		_spawn_zombie(true)

func _build_location() -> void:
	if variant == 1:
		_supply_point = Vector2(1720,900)
	elif variant == 2:
		_supply_point = Vector2(900,820)
	_prop(0, Vector2(1300,500))
	_prop(3, _depot)
	_prop(6, _supply_point)
	_prop(7, Vector2(1770,780) if variant != 1 else Vector2(1030,940))
	_prop(4, Vector2(1560,515))
	fire_sprite = _prop(5, _fire_point)
	for index in 7:
		if index != 3:
			_add_wall(Vector2(1055 + index * 85,690),1.0 if index in [0,6] else 0.12)
		_add_wall(Vector2(1055 + index * 85,360),1.0 if index % 2 == 0 else 0.4)
	for index in 3:
		_add_wall(Vector2(995,445 + index*82),0.5 if index == 2 else 1.0,true)
		_add_wall(Vector2(1630,445 + index*82),1.0 if index == 0 else 0.2,true)
	if variant == 1:
		_prop(7,Vector2(1780,310))
	elif variant == 2:
		_prop(3,Vector2(1530,590))
	# Deliberate groves, with full image clearance between rocks and trees.
	# Native-size sprites preserve the meadow's two-pixel blocks and root pivots.
	for row in 3:
		for column in 4:
			var point := Vector2(50+column*242+(row%2)*44,300+row*300)+Vector2([0,14,-24,10][column],[-28,38,-8,24][column])
			_tree(point,["oak","birch","young_oak"][posmod(row+column+variant,3)])
	for point in [Vector2(990,252),Vector2(1250,210),Vector2(1545,236),Vector2(1850,286)]:
		_tree(point if variant != 2 else point+Vector2(0,38),"young_oak" if variant == 1 else "oak")
	for point in [Vector2(860,590),Vector2(1850,480),Vector2(750,1040),Vector2(1550,1030),Vector2(420,1040),Vector2(1860,1030)]:
		_rock(point)
	_add_ground_props()

func _add_ground_props() -> void:
	# Separate seeded decoration RNG preserves combat and worker behavior.
	var decoration_rng:=RandomNumberGenerator.new()
	decoration_rng.seed=6193+variant*283
	var names: Array[String]=["grass_short","grass_short","grass_tall","clover","fern","flowers_white","flowers_yellow","mushrooms","pebbles","branch"]
	var occupied: Array[Rect2]=[]
	for attempt in 3000:
		if ground_props.size()>=150:break
		var point:=Vector2(decoration_rng.randf_range(35,1890),decoration_rng.randf_range(80,1055))
		if not _on_land(point,36):continue
		if variant==1 and point.y>780 and point.y<1030:continue
		var clearing: Vector2=(point-Vector2(1320,590))/Vector2(465,390)
		if clearing.length()<1.04:continue
		var decoration:=Scatter.new()
		decoration.setup(names[decoration_rng.randi_range(0,names.size()-1)],point)
		var bounds: Rect2=decoration.visual_bounds()
		var clear:=_clear_scenery(bounds)
		for wall in structures:
			if wall.footprint().grow(30).intersects(bounds):clear=false
		for previous in occupied:
			if previous.grow(6).intersects(bounds):clear=false
		if not clear:
			decoration.free()
			continue
		entities.add_child(decoration)
		ground_props.append(decoration)
		occupied.append(bounds)

func _prop(index: int, point: Vector2) -> Node2D:
	var prop := Prop.new()
	prop.kind = index
	prop.position = point
	entities.add_child(prop)
	_footprints.append(prop.footprint())
	scenery_bounds.append(prop.visual_bounds())
	scenery_kinds.append("camp")
	return prop

func _clear_scenery(bounds: Rect2) -> bool:
	for occupied in scenery_bounds:
		if occupied.grow(12).intersects(bounds):
			return false
	return true

func _outline_material() -> ShaderMaterial:
	var outline_style := ShaderMaterial.new()
	outline_style.shader = OUTLINE
	return outline_style

func _tree(point: Vector2, species: String) -> void:
	if not _on_land(point,24):
		return
	var texture: Texture2D = load("res://assets/environment/meadow/trees/%s_standing.png" % species)
	var offset := Vector2(-texture.get_width()*0.5,-texture.get_height()+4)
	var bounds := Rect2(point+offset,texture.get_size())
	if _clear_scenery(bounds):
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.material = _outline_material()
		sprite.centered = false
		sprite.offset = offset
		sprite.position = point
		entities.add_child(sprite)
		scenery_bounds.append(bounds)
		scenery_kinds.append("tree")
		_footprints.append(Rect2(point-Vector2(20,14),Vector2(40,28)))

func _rock(point: Vector2) -> void:
	if not _on_land(point,40):
		return
	var texture: Texture2D = load("res://assets/environment/meadow/props/boulder.png")
	var used := texture.get_image().get_used_rect()
	var offset := -Vector2(used.position)-Vector2(used.size.x*0.5,used.size.y)
	var bounds := Rect2(point+offset+Vector2(used.position),Vector2(used.size))
	if not _clear_scenery(bounds):
		return
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.material = _outline_material()
	sprite.centered = false
	sprite.offset = offset.snapped(Vector2(2,2))
	sprite.position = point
	entities.add_child(sprite)
	scenery_bounds.append(bounds)
	scenery_kinds.append("rock")
	_footprints.append(Rect2(point-Vector2(28,24),Vector2(56,28)))

func _add_wall(point: Vector2, progress: float, vertical := false) -> void:
	var wall := Structure.new()
	wall.position = point
	wall.progress = progress
	wall.health = wall.max_health*progress
	wall.vertical = vertical
	wall.sandbags = variant == 1
	entities.add_child(wall)
	structures.append(wall)

func _on_land(point: Vector2, margin := 12.0) -> bool:
	return point.x >= margin and point.x <= 1980-margin and point.y >= (220+margin if variant == 2 else margin) and point.y <= (960-margin if variant == 2 else 1120-margin)

func _add_light(point: Vector2) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1,1,1,0))
	var glow := GradientTexture2D.new()
	glow.gradient = gradient
	glow.width = 256
	glow.height = 256
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5,0.5)
	glow.fill_to = Vector2(1.0,0.5)
	var light := PointLight2D.new()
	light.texture = glow
	light.texture_scale = 2.25
	light.position = point - Vector2(0,40)
	light.color = Color(1.0,0.72,0.38)
	light.energy = 0.8
	add_child(light)

func _add_survivor(job: int, point: Vector2) -> void:
	if survivors.size() >= MAX_SURVIVORS:
		return
	var actor := Actor.new()
	actor.setup(false, job)
	var occupied_lanes: Array[int] = []
	for survivor in survivors:
		if survivor.role != 0 and survivor.health > 0:
			occupied_lanes.append(survivor.supply_lane)
	for lane in 4:
		if not occupied_lanes.has(lane):
			actor.supply_lane = lane
			break
	actor.position = _spawn_position(point)
	actor.previous_position = actor.position
	actor.home = actor.position
	actor.carrying = 0
	entities.add_child(actor)
	survivors.append(actor)

func _spawn_zombie(initial := false) -> void:
	if zombies.size() >= MAX_ZOMBIES:
		return
	var actor := Actor.new()
	actor.setup(true, 0)
	var side := _rng.randi_range(0,2)
	actor.position = Vector2(1930, _rng.randf_range(360,910))
	if side == 1:
		actor.position = Vector2(_rng.randf_range(950,1800), 230 if variant == 2 else 100)
	elif side == 2:
		actor.position = Vector2(_rng.randf_range(1000,1800), 945 if variant == 2 else 1050)
	if initial:
		actor.position = Vector2(_rng.randf_range(1710,1910),_rng.randf_range(600,900))
	actor.position = _spawn_position(actor.position)
	actor.previous_position = actor.position
	actor.phase = _rng.randf_range(0,4)
	actor.tint = Color(0.85,_rng.randf_range(0.8,1.0),0.79)
	entities.add_child(actor)
	zombies.append(actor)

func advance(delta: float) -> void:
	_accumulator += minf(delta,0.15)
	while _accumulator >= STEP:
		step(STEP)
		_accumulator -= STEP
	for actor in survivors+zombies:
		actor.render_interpolated(_accumulator/STEP)

func step(delta: float) -> void:
	elapsed += delta
	audio.advance(delta)
	_groan_clock += delta
	if _groan_clock > 6.0:
		_groan_clock = 0.0
		var nearby := _nearest(_fire_point,zombies,550)
		if nearby != null:
			audio.emit_sound("groan",nearby.position)
	_wave_clock += delta
	_spawn_clock += delta
	_replacement_clock += delta
	_navigation_clock += delta
	if _navigation_dirty:
		_rebuild_navigation()
	if _wave_clock > 25.0:
		_wave_clock = 0
		wave += 1
		stats.waves += 1
		for index in mini(4 + wave, 9):
			_spawn_zombie()
	if _spawn_clock > maxf(1.1, 3.5 - wave * 0.15):
		_spawn_clock = 0
		_spawn_zombie()
	if survivors.size() < MAX_SURVIVORS and _replacement_clock > 7.0:
		_replacement_clock = 0
		var roles: Array[int] = [0,0,0]
		for survivor in survivors:
			if survivor.health > 0:
				roles[survivor.role] += 1
		var missing := 0 if roles[0] < 2 else 1 if roles[1] < 1 else 2
		_add_survivor(missing,Vector2(1260,540))
	for actor in survivors + zombies:
		var before: Vector2 = actor.position
		actor.previous_position = before
		var previous_stride := int(actor.phase*2)
		var previous_death: float = actor.death_age
		actor.action = "idle"
		if actor.health > 0:
			if actor.team == 0:
				_survivor_ai(actor,delta)
			else:
				_zombie_ai(actor,delta)
		actor.animate(delta,actor.position-before)
		if actor.health > 0 and int(actor.phase*2) != previous_stride:
			audio.emit_sound("footstep",actor.position)
		if actor.team == 1 and previous_death < 0.48 and actor.death_age >= 0.48:
			audio.emit_sound("body_fall",actor.position)
	_step_bullets(delta)
	for group in [survivors,zombies]:
		for index in range(group.size()-1,-1,-1):
			var actor: Node2D = group[index]
			if actor.death_age > 4:
				group.remove_at(index)
				actor.queue_free()
	for index in range(effects.size()-1,-1,-1):
		effects[index].life -= delta
		effects[index].point += effects[index].velocity * delta
		if effects[index].life <= 0:
			effects.remove_at(index)
	fire_sprite.flame_frame = int(elapsed*6)
	fire_sprite.queue_redraw()
	var live_actors: Array[Node2D]=survivors+zombies
	for decoration in ground_props:
		decoration.advance(delta,elapsed,live_actors)
	effects_layer.queue_redraw()

func _nearest(point: Vector2, actors: Array[Node2D], limit: float) -> Node2D:
	var best: Node2D
	var distance := limit * limit
	for actor in actors:
		if actor.health <= 0:
			continue
		var candidate := point.distance_squared_to(actor.position)
		if candidate < distance:
			distance = candidate
			best = actor
	return best

func _survivor_ai(actor: Node2D, delta: float) -> void:
	var enemy := _nearest(actor.position,zombies,450 if actor.role == 0 else 230)
	if enemy != null and (actor.role != 1 or actor.position.distance_to(enemy.position) < 130) and _line_of_fire(actor.position,enemy.position):
		if actor.position.distance_to(enemy.position) < 120:
			_move(actor,actor.position + (actor.position-enemy.position).normalized() * 90,delta,90)
			if actor.action == "run":
				# The rifle poses have planted feet. Retreat with the walk cycle,
				# then plant and fire instead of sliding a standing shooter backward.
				return
		actor.action = "shoot"
		actor.aim = (enemy.position-actor.position).normalized()
		if actor.cooldown <= 0:
			_shoot(actor,enemy)
		return
	if actor.role == 0:
		var patrol: Vector2 = actor.home + Vector2(sin(elapsed * 0.17 + actor.home.x) * 85,cos(elapsed * 0.12 + actor.home.x) * 42)
		_move(actor,patrol,delta,88)
		return
	if actor.role == 2:
		_haul(actor,delta)
		return
	_build(actor,delta)

func _haul(actor: Node2D, delta: float) -> void:
	var offset := Vector2(-54+actor.supply_lane*36,64)
	var destination := (_supply_point if actor.carrying == 0 else _depot)+offset
	if actor.position.distance_to(destination) > 8:
		_move(actor,destination,delta,130)
		return
	actor.aim = Vector2.UP
	actor.action = "gather" if actor.carrying == 0 else "idle"
	actor.work += delta
	if actor.work > 1.2:
		actor.work = 0
		audio.emit_sound("timber",actor.position)
		if actor.carrying == 0:
			actor.carrying = 4
			stats.gathered += 4
			_burst(actor.position - Vector2(0,24),Color(0.62,0.44,0.23),5)
		else:
			supplies = mini(supplies + actor.carrying, 60)
			actor.carrying = 0

func _load_materials(actor: Node2D, delta: float) -> void:
	var destination := _depot+Vector2(-54+actor.supply_lane*36,64)
	if actor.position.distance_to(destination) > 8:
		_move(actor,destination,delta,112)
		return
	actor.action = "gather"
	actor.aim = Vector2.UP
	actor.work += delta
	if actor.work >= 0.6:
		actor.work = 0.0
		audio.emit_sound("timber",actor.position)
		actor.carrying = mini(supplies,3)
		supplies -= actor.carrying

func _work_spot(wall: Node2D, from: Vector2) -> Vector2:
	var best := Vector2.INF
	var nearest := INF
	var offsets := [Vector2(0,48),Vector2(0,-48)] if not wall.vertical else [Vector2(48,0),Vector2(-48,0)]
	for offset: Vector2 in offsets:
		var point := Vector2(_free_cell(wall.position+offset))*CELL_SIZE+CELL_CENTER
		if point.distance_to(wall.position) > 80 or wall.footprint().grow(20).has_point(point) or not _body_clear(point) or not _line_of_fire(point,wall.position):
			continue
		var distance := point.distance_squared_to(from)
		if distance < nearest:
			nearest = distance
			best = point
	return best

func _build(actor: Node2D, delta: float) -> void:
	var target: Node2D = actor.target if is_instance_valid(actor.target) else null
	if target != null and target.progress < 1.0:
		for damaged in structures:
			if damaged.progress >= 1.0 and damaged.health < damaged.max_health*0.5 and actor.position.distance_to(damaged.position) < 220:
				if not is_instance_valid(damaged.worker) or damaged.worker == actor or damaged.worker.health <= 0:
					target.worker = null
					target = null
					break
	if target != null and target.progress >= 1.0 and target.health >= target.max_health:
		target.worker = null
		target = null
	if target == null:
		var closest := INF
		for wall in structures:
			if wall.progress >= 1.0 and wall.health >= wall.max_health:
				continue
			if is_instance_valid(wall.worker) and wall.worker != actor and wall.worker.health > 0:
				continue
			var spot := _work_spot(wall,actor.position)
			if not spot.is_finite():
				continue
			var distance := actor.position.distance_squared_to(spot)
			if wall.progress >= 1.0 and wall.health < wall.max_health*0.65:
				distance *= 0.25
			if distance < closest:
				closest = distance
				target = wall
				actor.work_position = spot
	actor.target = target
	if target != null:
		target.worker = actor
	if target == null or (supplies <= 0 and actor.carrying == 0):
		_haul(actor,delta)
		return
	if actor.carrying == 0:
		_load_materials(actor,delta)
		return
	if not _body_clear(actor.work_position):
		actor.work_position = _work_spot(target,actor.position)
	if not actor.work_position.is_finite():
		target.worker = null
		actor.target = null
		return
	if actor.position.distance_to(actor.work_position) > 8:
		_move(actor,actor.work_position,delta,112)
		return
	actor.action = "build"
	actor.aim = (target.position-actor.position).normalized()
	actor.build_clock += delta
	if actor.build_clock >= 0.8:
		actor.build_clock = fmod(actor.build_clock,0.8)
		actor.build_struck = false
	# Spend carried materials exactly when the hammer reaches its contact frame.
	if actor.build_clock >= 0.4 and not actor.build_struck:
		actor.build_struck = true
		actor.carrying -= 1
		var previous_bounds: Rect2 = target.collision_bounds()
		if target.progress < 1.0:
			var next_bounds: Rect2 = target.collision_bounds(minf(target.progress+0.22,1.0))
			if next_bounds.has_area() and next_bounds != previous_bounds:
				for pawn in survivors+zombies:
					if pawn.health > 0 and next_bounds.grow(12).has_point(pawn.position):
						actor.carrying += 1
						return
			target.progress = minf(target.progress + 0.22,1.0)
			target.health = maxf(target.health,target.max_health * target.progress)
			if target.progress >= 1.0:
				stats.built += 1
		else:
			target.health = minf(target.health + 50,target.max_health)
			stats.repaired += 1
		target.queue_redraw()
		audio.emit_sound("hammer",target.position)
		if previous_bounds != target.collision_bounds():
			_navigation_dirty = true
		_burst(target.position - Vector2(0,25),Color(0.76,0.6,0.34),7)

func _zombie_ai(actor: Node2D, delta: float) -> void:
	var target := _nearest(actor.position,survivors,2000)
	if target == null:
		return
	var goal: Vector2 = target.position
	var barrier: Node2D
	var nearest := INF
	for wall in structures:
		var bounds: Rect2 = wall.collision_bounds()
		if not bounds.has_area():
			continue
		var contact := actor.position.clamp(bounds.position,bounds.end)
		var distance := actor.position.distance_to(contact)
		if distance < 90 and distance < nearest and _segment_hits_rect(actor.position,target.position,bounds.grow(12)):
			nearest = distance
			barrier = wall
			var normal := (actor.position-contact).normalized()
			if normal == Vector2.ZERO:
				normal = Vector2.DOWN
			goal = contact+normal*19
	actor.aim = (target.position-actor.position).normalized()
	if actor.position.distance_to(goal) > (7 if barrier != null else 40):
		_move(actor,goal,delta,42.0 + minf(wave * 2.0,18.0))
		return
	if barrier != null:
		actor.aim = (barrier.position-actor.position).normalized()
	actor.action = "attack"
	if actor.cooldown > 0:
		return
	actor.cooldown = 0.85
	if barrier != null:
		barrier.health = maxf(0.0,barrier.health - 21)
		if barrier.health <= 0:
			audio.emit_sound("fence_break",barrier.position)
			barrier.progress = 0.08
			stats.breaches += 1
			_navigation_dirty = true
			_burst(barrier.position,Color(0.45,0.30,0.16),12)
		barrier.queue_redraw()
	else:
		target.health -= 13
		target.hurt = 0.6

func _move(actor: Node2D, destination: Vector2, delta: float, speed: float) -> void:
	# Patrol/retreat goals can fall inside scenery. End at a reachable ground cell.
	if not _body_clear(destination):
		destination = Vector2(_free_cell(destination))*CELL_SIZE+CELL_CENTER
	if actor.position.distance_to(destination) < 6:
		actor.move_velocity = Vector2.ZERO
		actor.blocked_time = 0.0
		return
	if _clear_segment(actor.position,destination) and actor.blocked_time < 0.6 and actor.detour_time <= 0:
		actor.route.clear()
	elif actor.route_clock <= 0 and (actor.route_target.distance_to(destination) > 24 or actor.route.is_empty() or actor.blocked_time > 0.8):
		actor.route_target = destination
		actor.route_clock = 0.6
		actor.route = _route_around_bodies(actor,destination,actor.blocked_time > 0.6)
		if actor.blocked_time > 0.6:
			actor.detour_time = 1.5
		actor.blocked_time = 0.0
	# Skip grid stair-steps whenever the whole body can travel directly ahead.
	while actor.route.size() > 1 and _clear_segment(actor.position,actor.route[1]):
		actor.route.remove_at(0)
	while not actor.route.is_empty() and actor.position.distance_to(actor.route[0]) < 4:
		actor.route.remove_at(0)
	var waypoint: Vector2 = destination if actor.route.is_empty() else actor.route[0]
	if actor.route.is_empty() and not _clear_segment(actor.position,destination):
		actor.blocked_time += delta
		return
	var direction: Vector2 = (waypoint-actor.position).normalized()
	var before: Vector2 = actor.position
	var desired: Vector2 = direction*speed
	actor.move_velocity = actor.move_velocity.move_toward(desired,600*delta)
	var travel: Vector2 = actor.move_velocity*delta
	if travel.length() > before.distance_to(waypoint):
		travel = waypoint-before
	var proposed := before+travel
	if _clear_segment(before,proposed) and _agents_clear(actor,proposed):
		actor.position = proposed
	else:
		# Choose a clear forward side step; never reverse in place for a whole cycle.
		var best := INF
		for angle in [PI/4,-PI/4,PI/2,-PI/2]:
			var side_direction := direction.rotated(angle)
			var sidestep := before+side_direction*speed*delta
			if not _clear_segment(before,sidestep) or not _agents_clear(actor,sidestep):
				continue
			var score := sidestep.distance_squared_to(waypoint)
			# A consistent passing side keeps head-on pairs from mirroring each other.
			if angle < 0:
				score += 2.0
			if score < best:
				best = score
				actor.position = sidestep
				actor.move_velocity = side_direction*speed
	var movement: Vector2 = actor.position-before
	var progress := before.distance_to(waypoint)-actor.position.distance_to(waypoint)
	actor.blocked_time = actor.blocked_time+delta if progress < speed*delta*0.15 else maxf(0,actor.blocked_time-delta*0.25)
	if movement.length_squared() > 0.001:
		actor.action = "run"
		actor.aim = movement.normalized()
	else:
		actor.move_velocity = Vector2.ZERO

func _route_around_bodies(actor: Node2D, destination: Vector2, avoid_bodies: bool) -> PackedVector2Array:
	var start := _visible_cell(actor.position)
	var goal := _visible_cell(destination)
	var temporary: Array[Vector2i] = []
	if avoid_bodies:
		for other in survivors+zombies:
			if other == actor or other.health <= 0 or other.position.distance_to(actor.position) > 160:
				continue
			var center := _cell(other.position)
			for y in range(maxi(0,center.y-2),mini(GRID_SIZE.y,center.y+3)):
				for x in range(maxi(0,center.x-2),mini(GRID_SIZE.x,center.x+3)):
					var cell := Vector2i(x,y)
					if cell != start and cell != goal and not _navigation.is_point_solid(cell) and (Vector2(cell)*CELL_SIZE+CELL_CENTER).distance_to(other.position) < 25:
						_navigation.set_point_solid(cell,true)
						temporary.append(cell)
	var path := _navigation.get_point_path(start,goal,true)
	for cell in temporary:
		_navigation.set_point_solid(cell,false)
	return path

func _agents_clear(actor: Node2D, point: Vector2) -> bool:
	for other in survivors+zombies:
		if other != actor and other.health > 0 and point.distance_squared_to(other.position) < 24*24:
			return false
	return true

func _body_clear(point: Vector2, radius := 12.0) -> bool:
	if point.x < 830 or point.x > 1948 or not _on_land(point,radius):
		return false
	for footprint in _footprints:
		if footprint.grow(radius).has_point(point):
			return false
	for wall in structures:
		var bounds: Rect2 = wall.collision_bounds()
		if bounds.has_area() and bounds.grow(radius).has_point(point):
			return false
	return true

func _clear_segment(from: Vector2, to: Vector2) -> bool:
	if not _body_clear(from) or not _body_clear(to):
		return false
	for footprint in _footprints:
		if _segment_hits_rect(from,to,footprint.grow(11.99)):
			return false
	for wall in structures:
		var bounds: Rect2 = wall.collision_bounds()
		if bounds.has_area() and _segment_hits_rect(from,to,bounds.grow(11.99)):
			return false
	return true

func _visible_cell(point: Vector2) -> Vector2i:
	# The nearest cell can lie diagonally behind a wall corner. Require a clear
	# connection from the actual body position before using it as the path origin.
	var cell := _cell(point)
	var center := Vector2(cell)*CELL_SIZE+CELL_CENTER
	if not _navigation.is_point_solid(cell) and _clear_segment(point,center):
		return cell
	var result := _free_cell(point)
	var nearest := INF
	for y in range(maxi(0,cell.y-4),mini(GRID_SIZE.y,cell.y+5)):
		for x in range(maxi(0,cell.x-4),mini(GRID_SIZE.x,cell.x+5)):
			var candidate := Vector2i(x,y)
			var position_2d := Vector2(candidate)*CELL_SIZE+CELL_CENTER
			var distance := point.distance_squared_to(position_2d)
			if distance < nearest and not _navigation.is_point_solid(candidate) and _clear_segment(point,position_2d):
				nearest = distance
				result = candidate
	return result

func _spawn_position(point: Vector2) -> Vector2:
	var best := Vector2(_free_cell(point))*CELL_SIZE+CELL_CENTER
	if _body_clear(best) and _nearest(best,survivors+zombies,28) == null:
		return best
	var nearest := INF
	for y in GRID_SIZE.y:
		for x in range(52,GRID_SIZE.x):
			var candidate := Vector2(x,y)*CELL_SIZE+CELL_CENTER
			if _navigation.is_point_solid(Vector2i(x,y)) or not _body_clear(candidate):
				continue
			if _nearest(candidate,survivors+zombies,28) != null:
				continue
			var distance := point.distance_squared_to(candidate)
			if distance < nearest:
				nearest = distance
				best = candidate
	return best

func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL_SIZE),floori(point.y / CELL_SIZE)).clamp(Vector2i.ZERO,GRID_SIZE-Vector2i.ONE)

func _free_cell(point: Vector2) -> Vector2i:
	var cell := _cell(point)
	if not _navigation.is_point_solid(cell):
		return cell
	var result := cell
	var nearest := INF
	for y in range(maxi(0,cell.y-6),mini(GRID_SIZE.y,cell.y+7)):
		for x in range(maxi(0,cell.x-6),mini(GRID_SIZE.x,cell.x+7)):
			var candidate := Vector2i(x,y)
			var distance := point.distance_squared_to(Vector2(candidate)*CELL_SIZE+CELL_CENTER)
			if distance < nearest and not _navigation.is_point_solid(candidate):
				nearest = distance
				result = candidate
	return result

func _rebuild_navigation() -> void:
	_navigation_dirty = false
	_navigation_clock = 0
	for y in GRID_SIZE.y:
		for x in GRID_SIZE.x:
			# Match physical clearance; route shortcuts also sweep the full body.
			_navigation.set_point_solid(Vector2i(x,y),not _body_clear(Vector2(x,y)*CELL_SIZE+CELL_CENTER))
	for actor in survivors+zombies:
		actor.route.clear()
		actor.route_clock = 0.0

func _segment_hits_rect(from: Vector2, to: Vector2, rect: Rect2) -> bool:
	var start := 0.0
	var end := 1.0
	var direction := to-from
	for axis in 2:
		if absf(direction[axis]) < 0.0001:
			if from[axis] < rect.position[axis] or from[axis] > rect.end[axis]:
				return false
		else:
			var enter := (rect.position[axis]-from[axis])/direction[axis]
			var leave := (rect.end[axis]-from[axis])/direction[axis]
			start = maxf(start,minf(enter,leave))
			end = minf(end,maxf(enter,leave))
			if start > end:
				return false
	return true

func _line_of_fire(from: Vector2, to: Vector2) -> bool:
	for footprint in _footprints:
		if _segment_hits_rect(from,to,footprint):
			return false
	return true

func _shoot(actor: Node2D, enemy: Node2D) -> void:
	if bullets.size() >= MAX_BULLETS or not _line_of_fire(actor.position,enemy.position):
		return
	actor.cooldown = _rng.randf_range(0.55,0.9)
	actor.begin_shot()
	var muzzle: Vector2 = actor.position + actor.muzzle_offset()
	var destination: Vector2 = enemy.position + Vector2(0,-34)
	bullets.append({"point":muzzle,"velocity":(destination-muzzle).normalized()*780,"life":1.0})
	stats.shots += 1
	audio.emit_sound("rifle",actor.position)
	_burst(muzzle,Color(0.85,0.74,0.40),1)

func _step_bullets(delta: float) -> void:
	for index in range(bullets.size()-1,-1,-1):
		var bullet: Dictionary = bullets[index]
		var before: Vector2 = bullet.point
		bullet.point += bullet.velocity * delta
		bullet.life -= delta
		for enemy in zombies:
			if enemy.health <= 0:
				continue
			var chest: Vector2 = enemy.position + Vector2(0,-34)
			if chest.distance_to(Geometry2D.get_closest_point_to_segment(chest,before,bullet.point)) < 22:
				enemy.health -= 34
				enemy.hurt = 0.4
				_burst(chest,Color(0.50,0.12,0.10),4)
				if enemy.health <= 0:
					stats.kills += 1
				bullet.life = 0
				break
		if bullet.life <= 0:
			bullets.remove_at(index)

func _burst(point: Vector2, color: Color, count: int) -> void:
	for index in mini(count,MAX_EFFECTS-effects.size()):
		effects.append({"point":point,"velocity":Vector2(_rng.randf_range(-50,50),_rng.randf_range(-50,15)),"color":color,"life":_rng.randf_range(0.2,0.5)})

func _draw_effects() -> void:
	for bullet in bullets:
		var velocity: Vector2 = bullet.velocity
		effects_layer.draw_line(bullet.point,Vector2(bullet.point)-velocity.normalized()*24,Color(1.0,0.83,0.45,0.88),2)
	for effect in effects:
		var color: Color = effect.color
		color.a = minf(effect.life * 3.0,1.0)
		effects_layer.draw_rect(Rect2(effect.point,Vector2(3,3)),color)
