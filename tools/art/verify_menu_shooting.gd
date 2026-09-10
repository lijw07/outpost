extends SceneTree
## Focused menu-only action/scenery checks. Does not load menus or write player settings.
var failures:=0
var checks:=0
var rendered:=false
const ACTOR:=preload("res://scripts/ui/menu_demo_actor.gd")
const WORLD:=preload("res://scripts/ui/menu_demo_world.gd")
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func capture(view: SubViewport, file: String) -> void:
	if not rendered:return
	for frame in 3:
		await process_frame
		RenderingServer.force_draw(false)
	view.get_texture().get_image().save_png("res://output/menu-shooting/"+file+".png")
func run() -> void:
	rendered=DisplayServer.get_name()!="headless"
	DirAccess.make_dir_recursive_absolute("res://output/menu-shooting")
	var pawn:=ACTOR.new()
	pawn.setup(false,0)
	pawn.action="shoot"
	for direction in [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]:
		pawn.aim=direction
		pawn.shot_age=10
		pawn.animate(0.0)
		check(pawn.current_clip=="shoot" and pawn.current_frame%4==0,"holding aim uses planted rifle pose")
		pawn.begin_shot()
		check(pawn.current_frame%4==1 and pawn.flash>0,"a fired bullet triggers recoil and flash together")
		var clip: Dictionary=pawn.clips.shoot
		var muzzle: Vector2=clip.muzzles[pawn.current_frame]
		check(Rect2(Vector2.ZERO,pawn.body.texture.get_size()).has_point(muzzle),"muzzle lies within the drawn rifle frame")
		pawn.animate(0.09)
		check(pawn.current_frame%4==2 and pawn.flash==0,"shot settles after the brief flash")
		pawn.animate(0.08)
		check(pawn.current_frame%4==3,"recoil enters recovery")
		pawn.animate(0.12)
		check(pawn.current_frame%4==0,"a shot returns to steady aim without looping")
	for index in 16:
		check(pawn.clips.shoot.pivots[index].y==pawn.clips.shoot.frames[index].get_height(),"shooting pose preserves foot baseline")
	for direction in [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]:
		pawn.aim=direction
		pawn.armed_phase=0.0
		var poses: Dictionary={}
		for step in 4:
			pawn.animate(0.2,direction*15.0)
			poses[pawn.current_frame%4]=true
			check(pawn.current_clip=="move_shoot","movement selects the armed walk cycle")
			var phase_before: float=pawn.armed_phase
			var frame_before: int=pawn.current_frame
			pawn.begin_shot()
			check(pawn.armed_phase==phase_before and pawn.current_frame==frame_before,"firing never restarts or skips a footstep")
			check(pawn.moving_recoil.length()>0 and pawn.muzzle_offset().is_finite(),"moving shots have upper-body recoil and a valid muzzle")
		check(poses.size()==4,"distance advances all four armed walking poses")
		var forward_phase: float=pawn.armed_phase
		pawn.animate(0.2,-direction*15.0)
		check(pawn.armed_phase<forward_phase and pawn.aim==direction,"backpedaling reverses the gait while preserving aim")
		pawn.animate(0.2,direction.rotated(PI/2)*15.0)
		check(pawn.current_clip=="move_shoot" and pawn.aim==direction,"sideways movement also preserves target facing")
		var stopped_phase: float=pawn.armed_phase
		pawn.animate(0.1,Vector2.ZERO)
		check(pawn.current_clip=="shoot" and pawn.armed_phase==stopped_phase,"stopping plants the feet without losing firing state")
	pawn.equip(1,0,0)
	pawn.aim=Vector2.RIGHT
	pawn.action="shoot"
	pawn.armed_phase=0.0
	pawn.animate(0.2,Vector2(-15,0))
	check(pawn.current_clip=="survivor" and pawn.armed_phase<0,"separately drawn guns also reverse their walking gait on retreat")
	var separate_frame: int=pawn.current_frame
	pawn.begin_shot()
	check(pawn.current_frame==separate_frame and pawn.moving_recoil.length()>0,"separate gun recoil preserves the current footstep")
	check((pawn.muzzle_offset()-pawn.render_offset-pawn.weapon_grip()).dot(pawn.aim)>10,"separate weapon muzzle stays ahead of its grip during recoil")
	var gallery:=SubViewport.new()
	gallery.size=Vector2i(1000,700)
	gallery.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(gallery)
	var backdrop:=ColorRect.new()
	backdrop.size=Vector2(1000,700)
	backdrop.color=Color("35453a")
	gallery.add_child(backdrop)
	for row in 4:
		for col in 4:
			var actor:=ACTOR.new()
			actor.setup(false,0)
			actor.position=Vector2(130+col*245,156+row*170)
			actor.scale=Vector2(1.6,1.6)
			actor.action="shoot"
			actor.aim=[Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][row]
			actor.shot_age=[10.0,0.01,0.10,0.18][col]
			actor.flash=0.05 if col==1 else 0.0
			gallery.add_child(actor)
			actor._update_body()
			var label:=Label.new()
			label.text=["AIM","FIRE / RECOIL","SETTLE","RECOVER"][col]
			label.position=actor.position+Vector2(-56,3)
			label.add_theme_font_size_override("font_size",13)
			gallery.add_child(label)
	await capture(gallery,"shooting_poses")
	var pose_index:=0
	var label_index:=0
	for child in gallery.get_children():
		if child is Label:
			child.text=["STEP 1","STEP 2 + SHOT","STEP 3","STEP 4"][label_index%4]
			label_index+=1
		if child.get_script()!=ACTOR:continue
		child.velocity=child.aim*75.0
		child.armed_phase=(pose_index%4)*0.25+0.001
		child._update_body()
		pose_index+=1
	await capture(gallery,"moving_shooting_poses")
	gallery.queue_free()
	for variant in 3:
		var view:=SubViewport.new()
		view.size=Vector2i(960,540)
		view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var world:=WORLD.new()
		world.variant=variant
		view.add_child(world)
		view.canvas_transform=Transform2D(0,Vector2(0.5,0.5),0,Vector2.ZERO)
		check(world.ground_props.size()>=50 and world.ground_props.size()<=150,"world has a bounded, visible set of ground props")
		var types: Dictionary={}
		for prop in world.ground_props:
			types[prop.asset_name]=true
			check(world._on_land(prop.position,24),"decoration stays out of water")
			check(world._clear_scenery(prop.visual_bounds()),"ground props do not cover solid scenery")
		check(types.size()>=7,"grass, flowers, and small debris provide varied ground cover")
		var moving_shots:=0
		for tick in 900:
			var shots_before: int=world.stats.shots
			world.step(1.0/30.0)
			if world.stats.shots>shots_before:
				for actor in world.survivors:
					if actor.flash>0 and actor.action=="shoot" and actor.velocity.length_squared()>1:moving_shots+=1
		# Natural waves may die at range; force a clear retreat lane to exercise the trigger.
		var gunner: Node2D=world.survivors[1]
		var pursuer: Node2D=world.zombies[0]
		var lane:=Vector2.INF
		for y in range(300,900,48):
			for x in range(900,1760,48):
				var point:=Vector2(x,y)
				if world._body_clear(point) and world._body_clear(point-Vector2(24,0)) and world._body_clear(point+Vector2(100,0)) and world._line_of_fire(point,point+Vector2(100,0)) and world._clear_segment(point,point-Vector2(24,0)) and world._agents_clear(gunner,point) and world._agents_clear(gunner,point-Vector2(24,0)) and world._agents_clear(pursuer,point+Vector2(100,0)):
					lane=point
					break
			if lane.is_finite():break
		check(lane.is_finite(),"a clear ranged retreat lane exists")
		if lane.is_finite():
			gunner.position=lane
			gunner.previous_position=lane
			gunner.move_velocity=Vector2.ZERO
			gunner.route.clear()
			gunner.route_target=Vector2.INF
			gunner.melee_weapon={}
			gunner.firearm=load("res://scripts/ui/menu_demo_equipment.gd").firearms[1]
			gunner.wardrobe.firearm=gunner.firearm
			gunner.reset_ammo()
			gunner.reload_clock=0
			gunner.melee_clock=0
			gunner.cooldown=0
			pursuer.position=lane+Vector2(100,0)
			pursuer.health=85
			pursuer.death_age=0
			for tick in 30:
				var shots_before: int=world.stats.shots
				world.step(1.0/30.0)
				if world.stats.shots>shots_before and gunner.flash>0 and gunner.velocity.length_squared()>1:
					moving_shots+=1
					break
		check(moving_shots>0,"live survivors actually fire during retreats")
		check(world.stats.shots>0 and world.stats.kills>0,"combat remains active with shooting clips and ground props")
		var plant: Node2D
		for prop in world.ground_props:
			if prop.animated:
				plant=prop
				break
		var previous: float=plant.bend
		await process_frame
		await process_frame
		check(plant.bend==previous,"foliage freezes whenever menu simulation is paused")
		world.step(1.0/30.0)
		check(plant.bend!=previous,"foliage resumes with the same simulation clock")
		pawn.position=plant.position-Vector2(2,0)
		var passing: Array[Node2D]=[pawn]
		plant.advance(0.1,world.elapsed,passing)
		check(plant._contact>0,"passing actors bend foliage away from their feet")
		await capture(view,"world_%d"%variant)
		print("MENU SHOOTING: location ",variant," props ",world.ground_props.size()," shots ",world.stats.shots)
		view.queue_free()
		await process_frame
	pawn.free()
	if rendered:
		# Let the final viewport's stopped audio and render resources finish releasing.
		await create_timer(0.25).timeout
		RenderingServer.force_draw(false)
	print("MENU SHOOTING: ",checks," checks, ",failures," failed")
	quit(1 if failures else 0)
