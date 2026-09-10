extends SceneTree
## Equipment/combat regressions in the isolated UI-check profile.
const ACTOR := preload("res://scripts/ui/menu_demo_actor.gd")
const WORLD := preload("res://scripts/ui/menu_demo_world.gd")
const EQUIPMENT := preload("res://scripts/ui/menu_demo_equipment.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+message)
func run() -> void:
	if not "outpost-ui-checks" in OS.get_user_data_dir().to_lower():
		quit(2)
		return
	EQUIPMENT.prepare()
	var registered := true
	var follows := true
	var changes := false
	for outfit in 5:
		var actor := ACTOR.new()
		root.add_child(actor)
		actor.setup(false,0)
		actor.equip(1,outfit,0)
		for action in ["run","carry","build","shoot"]:
			for direction in [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]:
				var first := Vector2.INF
				for pose in 4:
					actor.action = action
					actor.carrying = 3 if action == "carry" else 0
					actor.aim = direction
					actor.phase = pose*0.25
					actor.armed_phase = actor.phase
					actor.build_clock = pose*0.2
					actor.velocity = direction*50
					actor._update_body()
					registered = registered and actor.clips[actor.current_clip].sockets[actor.current_frame].has("head")
					var anchor: Vector2 = actor.head_socket
					var attachment: Sprite2D = actor.wardrobe.hat if actor.wardrobe.hat.visible else actor.wardrobe.hair
					var offset := Vector2(-3 if actor.facing == 1 else 3 if actor.facing == 3 else 0,8) if outfit == 4 else Vector2.ZERO
					follows = follows and attachment.position.distance_to(anchor+offset) < 1.5
					if first.is_finite():
						changes = changes or first.distance_to(attachment.position) > 2
					else:
						first = attachment.position
		actor.free()
	check(registered,"all walk, carry, build, and armed frames have registered body sockets")
	check(follows and changes,"headwear follows changing head positions in every direction and action")
	var pose_actor := ACTOR.new()
	root.add_child(pose_actor)
	pose_actor.setup(false,0)
	pose_actor.equip(0,0,0)
	var upright := true
	var overhead := true
	var returns_to_rest := true
	for weapon in EQUIPMENT.weapons:
		pose_actor.melee_weapon = weapon
		pose_actor.wardrobe.weapon = weapon
		for direction in [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]:
			pose_actor.aim = direction
			pose_actor.action = "idle"
			pose_actor._update_body()
			var rest: Vector2 = pose_actor.weapon_grip()
			var tip: Vector2 = rest+pose_actor.weapon_direction()*pose_actor.weapon_scale()*0.88
			upright = upright and pose_actor.weapon_direction().is_equal_approx(Vector2.UP) and tip.y < rest.y-15
			pose_actor.action = "melee"
			pose_actor.melee_clock = float(weapon.cycle)*0.22
			pose_actor._update_body()
			var raised: Vector2 = pose_actor.weapon_grip()
			pose_actor.melee_clock = float(weapon.cycle)*0.42
			pose_actor._update_body()
			overhead = overhead and raised.y < rest.y-8 and pose_actor.weapon_grip().y > raised.y+12
			pose_actor.melee_clock = float(weapon.cycle)
			pose_actor._update_body()
			returns_to_rest = returns_to_rest and pose_actor.weapon_grip().distance_to(rest) < 1
	check(upright and overhead,"all sixteen melee weapons hold upright and strike downward in all four directions")
	check(returns_to_rest,"overhead strikes recover to the upright grip without snapping")
	var attached := true
	var bounded := true
	for direction in [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]:
		pose_actor.aim = direction
		for weapon in EQUIPMENT.weapons:
			pose_actor.melee_weapon = weapon
			pose_actor.wardrobe.weapon = weapon
			for tick in 41:
				pose_actor.action = "melee"
				pose_actor.melee_clock = float(weapon.cycle)*tick/40.0
				pose_actor._update_body()
				var joints: PackedVector2Array = pose_actor.arm_pose(true)
				attached = attached and joints[2].distance_to(pose_actor.weapon_grip()) < 2
				attached = attached and pose_actor.arm_pose(false)[2].distance_to(pose_actor.support_grip()) < 2
				bounded = bounded and joints[0].distance_to(joints[2]) < 29
	check(attached and bounded,"hands stay on melee grips through full swings without stretched arms")
	pose_actor.action = "run"
	pose_actor.velocity = Vector2.RIGHT*50
	pose_actor.aim = Vector2.RIGHT
	pose_actor.phase = 0.25
	pose_actor.animate(0.1,Vector2.RIGHT*2)
	var free_forward: Vector2 = pose_actor.relaxed_hand(false)
	pose_actor.phase = 0.75
	pose_actor.animate(0.1,Vector2.RIGHT*2)
	check(pose_actor.relaxed_hand(false).distance_to(free_forward)>10,"the free arm swings with the walking stride")
	pose_actor.free()
	var world := WORLD.new()
	root.add_child(world)
	for zombie in world.zombies:
		zombie.queue_free()
	world.zombies.clear()
	world._footprints.clear()
	for wall in world.structures:
		wall.queue_free()
	world.structures.clear()
	world._rebuild_navigation()
	var fighter: Node2D = world.survivors[0]
	fighter.position = Vector2(1200,700)
	var enemy := ACTOR.new()
	enemy.setup(true,0)
	enemy.position = Vector2(1240,700)
	world.add_child(enemy)
	world.zombies.append(enemy)
	fighter.action = "shoot"
	world._shoot(fighter,enemy)
	check(world.bullets.is_empty(),"the melee specialist cannot emit bullets even if given a shoot request")
	fighter.action = "idle"
	fighter.melee_clock = 0
	var health_before: float = enemy.health
	world._melee(fighter,enemy,float(fighter.melee_weapon.cycle)*0.2)
	fighter._update_body()
	var windup: Vector2 = fighter.weapon_grip()
	check(enemy.health == health_before and fighter.action == "melee","windup plants the actor without causing an early melee hit")
	world._melee(fighter,enemy,float(fighter.melee_weapon.cycle)*0.25)
	fighter._update_body()
	check(enemy.health < health_before and world.stats.melee_hits == 1 and windup.distance_to(fighter.weapon_grip()) > 8,"hands and weapon swing together and damage occurs at contact")
	var hit_health: float = enemy.health
	world._melee(fighter,enemy,float(fighter.melee_weapon.cycle)*0.2)
	check(enemy.health == hit_health and world.bullets.is_empty(),"one swing cannot hit twice or create a projectile")
	var gunner: Node2D = world.survivors[1]
	gunner.position = Vector2(1100,700)
	gunner.action = "shoot"
	gunner.aim = Vector2.RIGHT
	gunner._update_body()
	var aim_matches := true
	for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2(1,1).normalized(),Vector2(-1,-1).normalized()]:
		gunner.aim = direction
		gunner._update_body()
		aim_matches = aim_matches and absf(angle_difference(gunner.wardrobe.held.rotation,direction.angle())) < 0.001
	check(aim_matches,"equipment preserves exact target aiming in cardinal and diagonal directions")
	var top_views := true
	for direction in [Vector2.UP,Vector2.DOWN]:
		gunner.aim = direction
		gunner._update_body()
		top_views = top_views and gunner.wardrobe.held.texture.get_width() == 48
		var muzzle: Vector2 = gunner.muzzle_offset()-gunner.render_offset-gunner.weapon_grip()
		top_views = top_views and absf(muzzle.cross(direction)) < 0.01
	gunner.aim = Vector2.UP
	gunner._update_body()
	check(top_views,"vertical firearms use a centered top view with the muzzle on the aiming axis")
	check(gunner.arm_pose(true)[1].x < gunner.torso_socket.x-14 and gunner.arm_pose(false)[1].x > gunner.torso_socket.x+14,"rear-facing rifle elbows extend beyond the torso")
	gunner.aim = Vector2.RIGHT
	gunner._update_body()
	var rounds_before: int = gunner.rounds
	world._shoot(gunner,enemy)
	check(gunner.rounds == rounds_before-1 and world.bullets.size() == 1,"a firearm uses one round and emits a projectile")
	check(gunner.wardrobe.held.texture == EQUIPMENT.frame(gunner.firearm.get("atlas","firearms"),gunner.firearm.frame),"the drawn weapon matches the firearm which emitted the bullet")
	gunner.rounds = 0
	gunner.reload_clock = 0
	world._shoot(gunner,enemy)
	check(gunner.reload_clock > 0 and world.bullets.size() == 1,"an empty magazine starts reload without emitting a bullet")
	gunner.action = "reload"
	gunner._update_body()
	var reload_grip: Vector2 = gunner.weapon_grip()
	var reload_support: Vector2 = gunner.support_grip()
	gunner.reload_clock = float(gunner.firearm.reload)*0.7
	gunner._update_body()
	check(gunner.weapon_grip().is_equal_approx(reload_grip) and gunner.support_grip().is_equal_approx(reload_support) and is_equal_approx(gunner.wardrobe.held.rotation,gunner.aim.angle()),"refill timing does not animate hands or tilt the firearm")
	gunner.reload_clock = 0.001
	var reserve: int = gunner.reserve_ammo
	world._reload(gunner,float(gunner.firearm.reload)*0.4)
	check(gunner.rounds == 0,"reload cannot refill a magazine before the refill delay completes")
	world._reload(gunner,float(gunner.firearm.reload)*0.7)
	check(gunner.rounds == int(gunner.firearm.capacity) and gunner.reserve_ammo == reserve-gunner.rounds,"reload transfers only available reserve ammunition")
	gunner.rounds = 0
	gunner.reserve_ammo = 0
	gunner.reload_clock = 0.001
	gunner.position = world._ammo_depot+Vector2(-54+gunner.loadout_slot*36,64)
	world._reload(gunner,0.8)
	check(gunner.reserve_ammo == int(gunner.firearm.capacity)*3 and gunner.rounds == 0,"an exhausted survivor gathers reserve ammo at the camp supply before reloading")
	# Zombie contact is delayed, committed to a direction, and can miss.
	enemy.health = 85
	enemy.position = fighter.position+Vector2(35,0)
	enemy.aim = Vector2.LEFT
	enemy.attack_target = fighter
	enemy.attack_clock = 0
	enemy.attack_hit = false
	var survivor_health: float = fighter.health
	world._zombie_attack(enemy,0.2)
	var claw_windup: Vector2 = enemy.zombie_hand()
	check(fighter.health == survivor_health,"zombie windup cannot cause an early hit")
	world._zombie_attack(enemy,0.17)
	check(fighter.health == survivor_health-13 and enemy.zombie_hand().distance_to(claw_windup)>15,"zombie damage coincides with visible claw contact")
	world._zombie_attack(enemy,0.15)
	check(fighter.health == survivor_health-13,"a zombie strike only damages once")
	enemy.attack_clock = 0
	enemy.attack_hit = false
	fighter.position += Vector2(100,0)
	world._zombie_attack(enemy,0.4)
	check(fighter.health == survivor_health-13,"a survivor leaving claw range avoids the strike")
	# Route smoothing must respect the same bodies that required a detour.
	fighter.position = Vector2(1200,700)
	enemy.position = Vector2(1250,700)
	fighter.detour_time = 1.5
	check(not world._route_segment_clear(fighter,Vector2(1300,700)),"route smoothing cannot shortcut an active detour through another actor")
	# Regression from the supplied recording: an unopposed guard must not chase
	# a slowly drifting patrol goal in repeated one-frame walking bursts.
	for zombie in world.zombies:
		zombie.health = 0
	for other in world.survivors:
		if other != fighter:
			other.health = 0
	fighter.position = Vector2(1200,800)
	fighter.home = fighter.position
	fighter.patrol_point = Vector2.INF
	fighter.melee_clock = 0
	fighter.reload_clock = 0
	fighter.route.clear()
	fighter.route_clock = 0
	fighter.move_velocity = Vector2.ZERO
	fighter.combat_target = null
	var transitions := 0
	var last_moving := false
	var short_walks := 0
	var walk_ticks := 0
	var patrol_changes := 0
	var last_destination := Vector2.INF
	for tick in 600:
		world.elapsed += 1.0/30.0
		var before: Vector2 = fighter.position
		fighter.action = "idle"
		world._survivor_ai(fighter,1.0/30.0)
		fighter.animate(1.0/30.0,fighter.position-before)
		var moving: bool = fighter.velocity.length_squared() > 1
		if moving != last_moving:
			transitions += 1
			if not moving and walk_ticks < 8:
				short_walks += 1
			walk_ticks = 0
		walk_ticks += 1 if moving else 0
		last_moving = moving
		if fighter.patrol_point != last_destination:
			patrol_changes += 1
			last_destination = fighter.patrol_point
	print("PATROL TRACE: ",short_walks," short walking bursts, ",transitions," walk/idle transitions in 20 seconds")
	check(short_walks == 0 and transitions < 30 and patrol_changes >= 4,"an unopposed patrol walks between fixed destinations without rapid walk/idle jitter")
	world.queue_free()
	await process_frame
	print("EQUIPMENT CHECK: ",checks," checks, ",failures," failed")
	quit(1 if failures else 0)
