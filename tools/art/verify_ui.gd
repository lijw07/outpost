extends SceneTree

func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/art/ui_slices.json"))
	var checked := 0
	for entry: Dictionary in manifest["slices"]:
		var texture := load("res://" + str(entry["path"])) as Texture2D
		if texture == null or texture.get_width() != int(entry["rect"][2]) or texture.get_height() != int(entry["rect"][3]):
			push_error("UI import or size mismatch: " + str(entry["path"]))
			quit(1)
			return
		checked += 1
	var checkbox := load("res://assets/ui/widgets/checkbox_checked.png") as Texture2D
	if checkbox == null or checkbox.get_size() != Vector2(73, 69):
		push_error("Derived checkbox import failed")
		quit(1)
		return
	var theme := load("res://assets/ui/outpost_theme.tres") as Theme
	if theme == null:
		push_error("Existing UI theme failed to load")
		quit(1)
		return
	for type: StringName in theme.get_type_list():
		for style: StringName in theme.get_stylebox_list(type):
			var box := theme.get_stylebox(style, type) as StyleBoxTexture
			if box != null and box.texture == null:
				push_error("Missing theme texture: %s/%s" % [type, style])
				quit(1)
				return
	print("PASS: ", checked + 1, " UI textures loaded at their original dimensions; theme textures resolve.")
	quit()
