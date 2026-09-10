extends SceneTree
## Run only through the disposable-profile test runner.

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func check_navigation_cases() -> void:
	var demo: Node2D = load("res://scripts/ui/menu_demo_world.gd").new()
	root.add_child(demo)
	for pawn in demo.zombies:
		pawn.queue_free()
	demo.zombies.clear()
	for fence in demo.structures:
		fence.queue_free()
	demo.structures.clear()
	demo._footprints.clear()
	for index in range(demo.survivors.size()-1,0,-1):
		demo.survivors[index].queue_free()
		demo.survivors.remove_at(index)
	var walker: Node2D = demo.survivors[0]
	demo._add_wall(Vector2(1240,700),1.0)
	demo._rebuild_navigation()
	walker.position = Vector2(1240,620)
	var crossed := false
	for tick in 240:
		var before: Vector2 = walker.position
		demo._move(walker,Vector2(1240,780),1.0/30.0,120)
		walker.animate(1.0/30.0,walker.position-before)
		crossed = crossed or not demo._clear_segment(before,walker.position)
	check(not crossed and walker.position.distance_to(Vector2(1240,780)) < 8,"a survivor routes around a complete fence without crossing it or sticking on its corners")
	demo.structures[0].health = 0
	demo._rebuild_navigation()
	walker.position = Vector2(1100,700)
	walker.route.clear()
	walker.route_clock = 0.0
	demo._add_survivor(0,Vector2(1400,700))
	var oncoming: Node2D = demo.survivors[1]
	oncoming.position = Vector2(1400,700)
	var separated := true
	for tick in 360:
		for pawn in [walker,oncoming]:
			var before: Vector2 = pawn.position
			demo._move(pawn,Vector2(1400,700) if pawn == walker else Vector2(1100,700),1.0/30.0,120)
			pawn.animate(1.0/30.0,pawn.position-before)
			separated = separated and demo._agents_clear(pawn,pawn.position)
	check(separated and walker.position.distance_to(Vector2(1400,700)) < 8 and oncoming.position.distance_to(Vector2(1100,700)) < 8,"head-on survivors pass each other without overlap or a movement stalemate")
	walker.position = Vector2(1100,700)
	oncoming.position = Vector2(1240,700)
	walker.route.clear()
	walker.route_clock = 0.0
	for tick in 360:
		var before: Vector2 = walker.position
		demo._move(walker,Vector2(1400,700),1.0/30.0,120)
		walker.animate(1.0/30.0,walker.position-before)
	check(walker.position.distance_to(Vector2(1400,700)) < 8,"a stationary character does not permanently block another character's route")
	demo.queue_free()
	await process_frame

func run() -> void:
	if not "outpost-ui-checks" in OS.get_user_data_dir().to_lower():
		push_error("Use tests/run_ui_checks.py for background checks.")
		quit(2)
		return
	var controller: Script = load("res://scripts/ui/menu_background.gd")
	if "--rotation-reload" in OS.get_cmdline_user_args():
		var saved := ConfigFile.new()
		check(saved.load(controller.ROTATION_PATH) == OK, "previous process saved its scenery choice")
		var last: int = saved.get_value("rotation", "last", -1)
		var restarted: Control = controller.new()
		root.add_child(restarted)
		check(controller.session_location != last, "a fresh application process advances to a different scene")
		restarted.queue_free()
		await process_frame
		print("BACKGROUND CHECK: ", checks, " checks, ", failures, " failed")
		quit(1 if failures else 0)
		return
	var path := "user://background_rotation_test.cfg"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var previous := -1
	for cycle in 12:
		var seen: Array[int] = []
		for draw in 3:
			var chosen: int = controller.next_location(path)
			check(chosen != previous, "adjacent launches never repeat")
			check(not seen.has(chosen), "each shuffled deck visits every location")
			seen.append(chosen)
			previous = chosen
	var corrupt := ConfigFile.new()
	corrupt.set_value("rotation", "last", "invalid")
	corrupt.set_value("rotation", "remaining", [-50, "bad", 9000, 1, 1])
	corrupt.save(path)
	check(controller.next_location(path) == 1, "malformed rotation entries are discarded")
	DirAccess.remove_absolute(path)
	var pawn: Node2D = load("res://scripts/ui/menu_demo_actor.gd").new()
	pawn.setup(false,0)
	pawn.action = "run"
	for frame in 30:
		pawn.animate(1.0/30.0,Vector2.ZERO)
	check(pawn.phase == 0.0 and pawn.action == "idle", "blocked feet stop instead of walking in place")
	pawn.animate(1.0/30.0,Vector2(0,-8))
	check(pawn.phase > 0 and pawn.velocity.y < 0, "walking animation advances with actual travel")
	pawn.carrying = 3
	pawn.animate(0.01,Vector2.RIGHT)
	check(pawn.current_clip == "carry", "loaded workers use the two-handed carrying poses")
	pawn.action = "build"
	pawn.build_clock = 0.41
	pawn.animate(0.01)
	check(pawn.current_clip == "build" and pawn.current_frame % 4 == 2, "hammer contact uses the planted construction pose")
	var registered := true
	for clip_name in ["survivor","carry","build"]:
		var clip: Dictionary = pawn.clips[clip_name]
		for frame in clip.frames.size():
			if not is_equal_approx(clip.pivots[frame].y,clip.frames[frame].get_height()):
				registered = false
	check(registered,"all live action frames share their foot baseline without per-frame scaling")
	pawn.action = "run"
	pawn.animate(0.01,Vector2.RIGHT)
	check(pawn.build_clock == 0 and not pawn.build_struck,"leaving a work site resets the hammer cycle")
	pawn.previous_position = Vector2(100,100)
	pawn.position = Vector2(108,100)
	pawn.render_interpolated(0.5)
	check(pawn.position == Vector2(108,100) and pawn.body.position == Vector2(-4,0),"render interpolation smooths motion without moving the collision body")
	pawn.aim = Vector2(1,0.9)
	pawn._update_body()
	var diagonal_facing: int = pawn.facing
	pawn.aim = Vector2(0.9,1)
	pawn._update_body()
	check(pawn.facing == diagonal_facing,"small diagonal steering changes do not flicker between sprite directions")
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		pawn.aim = direction
		check((pawn.muzzle_offset()-Vector2(0,-34)).normalized().is_equal_approx(direction), "muzzle follows aiming direction")
	pawn.free()
	var corpse: Node2D = load("res://scripts/ui/menu_demo_actor.gd").new()
	corpse.setup(true,0)
	corpse.health = 0
	corpse.aim = Vector2.RIGHT
	corpse.animate(0.17)
	check(corpse.current_clip == "death" and corpse.current_frame % 4 == 1,"zombie death enters the buckle pose")
	corpse.animate(0.5)
	check(corpse.current_frame % 4 == 3 and corpse.body.rotation == 0,"zombie lands in a drawn prone pose without rotating the standing sprite")
	corpse.animate(1.0)
	check(corpse.current_frame % 4 == 3 and corpse.body.modulate.a == 1,"the final corpse pose holds without looping or disappearing early")
	corpse.free()
	await check_navigation_cases()
	var settings := root.get_node("Settings")
	settings.set_reduce_motion(false)
	for scene_path: String in controller.LOCATIONS:
		var landscape: Control = load(scene_path).instantiate()
		root.add_child(landscape)
		await process_frame
		await process_frame
		check(landscape.simulation.survivors.size() == 4 and landscape.simulation.zombies.size() > 0, "live gameplay starts with survivors and incoming zombies")
		check(landscape.mouse_filter == Control.MOUSE_FILTER_IGNORE, "landscape cannot intercept menu input")
		var start: float = landscape.elapsed
		await create_timer(0.08).timeout
		check(landscape.elapsed > start, "environment animates")
		settings.set_reduce_motion(true)
		start = landscape.elapsed
		await create_timer(0.08).timeout
		check(landscape.elapsed == start and not landscape.is_processing(), "Reduce Motion freezes environmental effects immediately")
		settings.set_reduce_motion(false)
		await create_timer(0.08).timeout
		check(landscape.elapsed > start, "animation resumes without restarting its timeline")
		var other: Control = load(scene_path).instantiate()
		root.add_child(other)
		check(other.simulation != landscape.simulation, "simultaneous demos have independent world state")
		other.queue_free()
		landscape.set_process(false)
		var demo: Node2D = landscape.simulation
		demo._add_survivor(0,Vector2(1310,750))
		check(demo.survivors.size() == 4,"even direct spawning cannot exceed four survivors")
		var collision_sections := true
		var open_sections := true
		for fence in demo.structures:
			var saved_progress: float = fence.progress
			var saved_health: float = fence.health
			fence.progress = 0.4
			fence.health = 50.0
			var bounds: Rect2 = fence.collision_bounds()
			var center: Vector2 = bounds.get_center()
			var crossing := Vector2(40,0) if fence.vertical else Vector2(0,40)
			if demo._body_clear(center) or demo._clear_segment(center-crossing,center+crossing):
				collision_sections = false
			var end: Vector2 = fence.footprint().end-Vector2(1,1)
			if bounds.has_point(end):
				open_sections = false
			fence.progress = saved_progress
			fence.health = saved_health
		check(collision_sections,"every visible partial fence section blocks bodies and swept crossings in both orientations")
		check(open_sections,"unbuilt fence sections have no invisible collision")
		var builder: Node2D = demo.survivors[2]
		var test_wall: Node2D = demo.structures[0]
		var old_position: Vector2 = builder.position
		var old_progress: float = test_wall.progress
		var old_health: float = test_wall.health
		builder.target = test_wall
		builder.work_position = demo._work_spot(test_wall,builder.position)
		builder.position = builder.work_position
		builder.carrying = 3
		builder.build_clock = 0.0
		builder.build_struck = false
		test_wall.progress = 0.0
		demo._build(builder,0.39)
		check(builder.carrying == 3 and test_wall.progress == 0,"raising the hammer does not spend material or grow a fence")
		demo._build(builder,0.02)
		check(builder.carrying == 2 and is_equal_approx(test_wall.progress,0.22),"hammer contact spends one carried material and builds one stage")
		demo._build(builder,0.15)
		check(builder.carrying == 2 and is_equal_approx(test_wall.progress,0.22),"hammer recovery cannot spend the same strike twice")
		test_wall.progress = 1.0
		test_wall.health = 100.0
		builder.build_clock = 0.39
		builder.build_struck = false
		demo._build(builder,0.02)
		check(builder.carrying == 1 and test_wall.health == 150.0,"repair contact restores fence health using one carried material")
		builder.position = old_position
		builder.target = null
		builder.carrying = 0
		builder.action = "idle"
		builder.animate(0.01)
		test_wall.worker = null
		test_wall.progress = old_progress
		test_wall.health = old_health
		var placement_clear := true
		for index in demo.scenery_bounds.size():
			if demo.scenery_kinds[index] not in ["tree","rock"]:
				continue
			for other_index in demo.scenery_bounds.size():
				if index != other_index and demo.scenery_bounds[index].intersects(demo.scenery_bounds[other_index]):
					placement_clear = false
		check(placement_clear, "tree and rock artwork never overlap other scenery")
		var work_spots_clear := true
		for wall in demo.structures:
			var spot: Vector2 = demo._work_spot(wall,Vector2(1310,750))
			if not spot.is_finite() or wall.footprint().grow(20).has_point(spot) or not demo._body_clear(spot):
				work_spots_clear = false
		check(work_spots_clear,"every wall has a reachable work spot outside its future footprint")
		var body_errors := 0
		var overlapping_bodies := 0
		var sliding_feet := 0
		var stalled_workers := 0
		var too_many_survivors := false
		var crossed_solid := false
		var spawned_on_screen := false
		var idle_streaks := {}
		for tick in 7200:
			demo.step(1.0 / 30.0)
			too_many_survivors = too_many_survivors or demo.survivors.size() > 4
			for undead in demo.zombies:
				spawned_on_screen = spawned_on_screen or not demo._outside_view(undead.spawn_position)
			if tick % 30 != 0:
				continue
			for actor in demo.survivors+demo.zombies:
				if actor.health <= 0:
					continue
				if not demo._body_clear(actor.position):
					body_errors += 1
				if not demo._clear_segment(actor.previous_position,actor.position):
					crossed_solid = true
				if not demo._agents_clear(actor,actor.position):
					overlapping_bodies += 1
				if actor.action == "run" and actor.velocity.length_squared() < 1:
					sliding_feet += 1
				if actor.team == 0 and actor.role != 0:
					var id: int = actor.get_instance_id()
					idle_streaks[id] = int(idle_streaks.get(id,0))+1 if actor.action == "idle" else 0
					if idle_streaks[id] > 15:
						stalled_workers += 1
		check(body_errors == 0,"four-minute run keeps every live body on land and outside solid scenery")
		check(not crossed_solid,"actors cannot tunnel through built fence sections or props between ticks")
		check(not too_many_survivors,"the four-survivor cap persists through deaths and replacements")
		check(not spawned_on_screen,"every zombie begins fully outside the visible menu, including wave spawns")
		check(overlapping_bodies == 0,"survivors and zombies share body separation")
		check(sliding_feet == 0,"moving poses always correspond to actual movement")
		check(stalled_workers == 0,"workers do not remain idle against an unreachable work spot")
		check(demo.stats.shots > 20 and demo.stats.kills > 0, "survivors fire real projectiles and defeat zombies")
		check(demo.stats.melee_hits > 0,"survivors land timed melee strikes during live combat")
		check(demo.stats.built > 2, "builders complete new defensive walls")
		check(demo.stats.gathered > 0, "haulers gather and deliver supplies")
		check(demo.stats.waves >= 4, "new waves keep the simulation running")
		check(demo.stats.breaches > 0, "zombies can damage and breach built defenses")
		check(demo.zombies.size() <= demo.MAX_ZOMBIES and demo.bullets.size() <= demo.MAX_BULLETS and demo.effects.size() <= demo.MAX_EFFECTS and demo.fields.size() <= 6, "long-running demo keeps actors and effects bounded")
		check(demo.supplies >= 0 and demo.supplies <= 60, "construction never spends unavailable resources")
		check(demo.audio.players.size() == 10 and demo.audio.events > 0,"gameplay emits sound events through a bounded voice pool")
		print("DEMO ",demo.variant," after 240 seconds: ",demo.stats)
		landscape.queue_free()
		await process_frame
	var first: Control = controller.new()
	root.add_child(first)
	var selected_path: String = first.location.scene_file_path
	first.queue_free()
	await process_frame
	var returning: Control = controller.new()
	root.add_child(returning)
	check(returning.location.scene_file_path == selected_path, "returning to menu keeps the current session's location")
	returning.queue_free()
	await process_frame
	print("BACKGROUND CHECK: ", checks, " checks, ", failures, " failed")
	quit(1 if failures else 0)
