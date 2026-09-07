extends Node

const SAVE_DIR := "user://saves"
const MAX_SLOTS := 6
const MAX_NAME_LENGTH := 14

func list_saves() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return saves
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".cfg"):
			continue
		var save := read_save(file_name.get_basename())
		if not save.is_empty():
			saves.append(save)
	saves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["last_played"] > b["last_played"])
	return saves

func read_save(id: String) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(_path_for(id)) != OK:
		return {}
	return {
		"id": id,
		"character_name": config.get_value("character", "name", "UNNAMED"),
		"created": config.get_value("meta", "created", 0),
		"last_played": config.get_value("meta", "last_played", 0),
	}

func can_create() -> bool:
	return list_saves().size() < MAX_SLOTS

func create_save(raw_name: String) -> Dictionary:
	var clean := sanitize_name(raw_name)
	if clean.is_empty() or not can_create():
		return {}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var now := int(Time.get_unix_time_from_system())
	var id := "%s_%d" % [clean.to_lower().replace(" ", "_"), now]
	var config := ConfigFile.new()
	config.set_value("character", "name", clean)
	config.set_value("meta", "created", now)
	config.set_value("meta", "last_played", now)
	config.save(_path_for(id))
	return read_save(id)

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

func format_timestamp(unix_time: int) -> String:
	if unix_time <= 0:
		return "NEVER"
	var stamp := Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02d %02d:%02d" % [stamp.year, stamp.month, stamp.day, stamp.hour, stamp.minute]

func _path_for(id: String) -> String:
	return "%s/%s.cfg" % [SAVE_DIR, id]
