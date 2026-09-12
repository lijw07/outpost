extends SceneTree

func _initialize() -> void:
	var skin: Resource = load("res://assets/ui/meadow/default_skin.tres")
	var result: Error = ResourceSaver.save(skin.make_theme(), "res://assets/ui/meadow/meadow_theme.tres")
	print("MEADOW_THEME ", error_string(result))
	quit(result)
