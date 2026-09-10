extends SceneTree
const Appearance := preload("res://scripts/characters/appearance.gd")
const Composer := preload("res://scripts/characters/compositor.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: "+label)
func run() -> void:
	if not "outpost-ui-checks" in OS.get_user_data_dir().to_lower():
		quit(2)
		return
	var saves := root.get_node("SaveManager")
	for save: Dictionary in saves.list_saves():
		saves.delete_save(save.id)
	var selected := Appearance.defaults()
	selected.merge({"sex":"female","skin":"deep","hair":"ponytail","hair_color":"silver","eye_color":"green","top":"jacket","top_color":"purple","pants":"shorts","pants_color":"khaki","shoes":"loafers","shoes_color":"brown"},true)
	var requested := selected.duplicate(true)
	requested["armor"] = "plate_carrier"
	requested["equipment"] = {"hat":"helmet"}
	var save: Dictionary = saves.create_save("CUSTOM QA",requested)
	check(save.appearance == selected,"all creator choices survive saving")
	check(save.equipment.is_empty(),"creation never grants world equipment")
	check(saves.read_save(save.id).appearance == selected,"appearance round-trips through disk")
	var duplicate: Dictionary = saves.create_save("CUSTOM QA",Appearance.defaults())
	check(save.id != duplicate.id,"same-name survivors never overwrite each other")
	var legacy := ConfigFile.new()
	legacy.set_value("character","name","LEGACY QA")
	legacy.save("user://saves/legacy_modular_qa.cfg")
	check(saves.read_save("legacy_modular_qa").appearance == Appearance.defaults(),"old survivors receive compatible appearance defaults")
	check(Appearance.sanitize({"sex":4,"skin":"invalid","top":"field_jacket"}) == Appearance.defaults(),"invalid and non-starter choices are rejected")
	for sex: String in Appearance.OPTIONS.sex:
		for top: String in Appearance.OPTIONS.top:
			for pants: String in Appearance.OPTIONS.pants:
				for shoes: String in Appearance.OPTIONS.shoes:
					var profile := selected.duplicate()
					profile.merge({"sex":sex,"top":top,"pants":pants,"shoes":shoes},true)
					for facing in 4:
						var pixels := Composer.compose(profile,facing)
						check(pixels.get_size() == Composer.CANVAS and pixels.get_used_rect().size.y>=22*Composer.DETAIL,"starter garments assemble into a complete bounded character")
	for hat in ["cap","helmet","ghillie_hood"]:
		for facing in 4:
			var bald := selected.duplicate()
			bald.hair = "bald"
			var first := Composer.compose(bald,facing,0,{"hat":hat})
			for hair: String in Appearance.OPTIONS.hair:
				var dressed := selected.duplicate()
				dressed.hair = hair
				var second := Composer.compose(dressed,facing,0,{"hat":hat})
				check(first.get_region(Rect2i(0,0,Composer.CANVAS.x,13*Composer.DETAIL)).get_data() == second.get_region(Rect2i(0,0,Composer.CANVAS.x,13*Composer.DETAIL)).get_data(),"hair cannot protrude through hat crowns")
	for item: String in Appearance.WORLD_EQUIPMENT:
		var worn := {Appearance.WORLD_EQUIPMENT[item].slot:item}
		for facing in 4:
			check(Composer.compose(selected,facing,1,worn).get_used_rect().has_area(),"world equipment supports every direction and walking")
	var idle := Composer.compose(selected,0,0)
	var walking := Composer.compose(selected,0,1)
	check(idle.get_data() != walking.get_data(),"gameplay has a distinct walking pose")
	check(idle.get_region(Rect2i(0,0,Composer.CANVAS.x,17*Composer.DETAIL)).get_data() == walking.get_region(Rect2i(0,0,Composer.CANVAS.x,17*Composer.DETAIL)).get_data(),"walking preserves head and hair attachment")
	var creator: Control = load("res://scenes/ui/panels/character_creator.tscn").instantiate()
	root.add_child(creator)
	creator.open()
	check(not creator.preview.has_method("_process"),"creator preview stays static")
	var before: int = saves.list_saves().size()
	check(creator.create_button.disabled,"empty name cannot create a survivor")
	for key: String in Appearance.OPTIONS:
		var previous: String = creator.profile[key]
		creator.cycle(key,1)
		check(creator.profile[key] != previous,"each creator selector changes its option")
	creator.cancelled.emit()
	check(saves.list_saves().size() == before,"cancelling does not write a survivor")
	creator.queue_free()
	await process_frame
	root.get_node("GameSession").save_id = save.id
	var game: Node2D = load("res://scenes/world/game.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	check(game.renderer.player.appearance == selected,"gameplay loads the chosen character appearance")
	check(is_equal_approx(game.renderer.player.body.texture.get_height()*game.renderer.player.body.pixel_size,2.0),"source detail does not enlarge the gameplay character")
	check(game.renderer.player.equipment.is_empty(),"new survivor starts without loot equipment")
	game.queue_free()
	await process_frame
	for entry: Dictionary in saves.list_saves():
		saves.delete_save(entry.id)
	root.get_node("GameSession").save_id = ""
	root.get_node("UiAudio").stop_all()
	await create_timer(0.2).timeout
	print("CHARACTER CHECK: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
