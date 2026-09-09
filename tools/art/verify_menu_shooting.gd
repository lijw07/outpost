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
		await RenderingServer.frame_post_draw
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
		for tick in 900:world.step(1.0/30.0)
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
	print("MENU SHOOTING: ",checks," checks, ",failures," failed")
	quit(1 if failures else 0)
