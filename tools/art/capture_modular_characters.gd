extends SceneTree
const Composer := preload("res://scripts/characters/compositor.gd")
const Appearance := preload("res://scripts/characters/appearance.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var result := Image.create(4*32*Composer.DETAIL,6*40*Composer.DETAIL,false,Image.FORMAT_RGBA8)
	result.fill(Color("33443e"))
	for row in 6:
		var profile := Appearance.defaults()
		profile.sex = "female" if row%2 else "male"
		profile.hair = Appearance.OPTIONS.hair[row%5]
		profile.hair_color = Appearance.OPTIONS.hair_color[row]
		profile.skin = Appearance.OPTIONS.skin[row]
		profile.top = Appearance.OPTIONS.top[row%3]
		profile.top_color = Appearance.OPTIONS.top_color[row]
		var worn := {}
		if row == 3: worn = {"hat":"cap","bag":"backpack"}
		if row == 4: worn = {"hat":"helmet","armor":"plate_carrier","outer":"field_jacket","legs":"cargo_pants","feet":"combat_boots","bag":"rucksack"}
		if row == 5: worn = {"hat":"ghillie_hood","outer":"ghillie_jacket","legs":"ghillie_pants","bag":"rucksack"}
		for facing in 4:
			result.blend_rect(Composer.compose(profile,facing,0,worn),Rect2i(Vector2i.ZERO,Composer.CANVAS),Vector2i(facing*32+4,row*40+4)*Composer.DETAIL)
	DirAccess.make_dir_recursive_absolute("user://modular-review")
	result.resize(768,1440,Image.INTERPOLATE_NEAREST)
	result.save_png("user://modular-review/characters.png")
	print("MODULAR CAPTURE: ",OS.get_user_data_dir()+"/modular-review/characters.png")
	quit()
