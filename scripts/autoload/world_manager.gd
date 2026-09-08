extends Node

const WORLD_DIR := "user://worlds"
const MAX_WORLDS := 6
const MAX_NAME_LENGTH := 16

func list_worlds() -> Array[Dictionary]:
	var worlds: Array[Dictionary] = []
	var dir := DirAccess.open(WORLD_DIR)
	if dir == null:
		return worlds
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".cfg"):
			continue
		var world := read_world(file_name.get_basename())
		if not world.is_empty():
			worlds.append(world)
	worlds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["last_played"] > b["last_played"])
	return worlds

func read_world(id: String) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(_path_for(id)) != OK:
		return {}
	return {
		"id": id,
		"world_name": config.get_value("world", "name", "UNNAMED"),
		"seed": config.get_value("world", "seed", 0),
		"created": config.get_value("meta", "created", 0),
		"last_played": config.get_value("meta", "last_played", 0),
	}

func can_create() -> bool:
	return list_worlds().size() < MAX_WORLDS

func create_world(raw_name: String, chosen_seed: int = 0) -> Dictionary:
	var clean := sanitize_name(raw_name)
	if clean.is_empty() or not can_create():
		return {}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORLD_DIR))
	var now := int(Time.get_unix_time_from_system())
	var id := "%s_%d" % [clean.to_lower().replace(" ", "_"), now]
	var config := ConfigFile.new()
	config.set_value("world", "name", clean)
	config.set_value("world", "seed", chosen_seed if chosen_seed != 0 else randi())
	config.set_value("meta", "created", now)
	config.set_value("meta", "last_played", now)
	config.save(_path_for(id))
	return read_world(id)

func delete_world(id: String) -> bool:
	var path := _path_for(id)
	if not FileAccess.file_exists(path):
		return false
	var dir := DirAccess.open(WORLD_DIR)
	if dir == null:
		return false
	return dir.remove(path.get_file()) == OK

func touch(id: String) -> void:
	var config := ConfigFile.new()
	if config.load(_path_for(id)) != OK:
		return
	config.set_value("meta", "last_played", int(Time.get_unix_time_from_system()))
	config.save(_path_for(id))

func sanitize_name(raw_name: String) -> String:
	var clean := ""
	for character: String in raw_name.to_upper():
		if character.is_valid_identifier() or character == " " or character.is_valid_int():
			clean += character
	return clean.strip_edges().substr(0, MAX_NAME_LENGTH)

func seed_label(value: int) -> String:
	return "SEED %d" % absi(value)

func _path_for(id: String) -> String:
	return "%s/%s.cfg" % [WORLD_DIR, id]
