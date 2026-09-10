extends Node

const Appearance := preload("res://scripts/characters/appearance.gd")
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
		"appearance": Appearance.sanitize(config.get_value("character", "appearance", {})),
		"equipment": Appearance.equipment(config.get_value("character", "equipment", {})),
		"created": config.get_value("meta", "created", 0),
		"last_played": config.get_value("meta", "last_played", 0),
	}

func can_create() -> bool:
	return list_saves().size() < MAX_SLOTS

func create_save(raw_name: String, appearance: Dictionary = {}) -> Dictionary:
	var clean := sanitize_name(raw_name)
	if clean.is_empty() or not can_create():
		return {}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var now := int(Time.get_unix_time_from_system())
	var id := "%s_%d" % [clean.to_lower().replace(" ", "_"), now]
	var base_id := id
	var suffix := 1
	while FileAccess.file_exists(_path_for(id)):
		id = "%s_%d" % [base_id,suffix]
		suffix += 1
	var config := ConfigFile.new()
	config.set_value("character", "appearance", Appearance.sanitize(appearance))
	config.set_value("character", "equipment", {})
	config.set_value("character", "name", clean)
	config.set_value("meta", "created", now)
	config.set_value("meta", "last_played", now)
	if config.save(_path_for(id)) != OK:
		return {}
	return read_save(id)

func delete_save(id: String) -> bool:
	var path := _path_for(id)
	if not FileAccess.file_exists(path):
		return false
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return false
	return dir.remove(path.get_file()) == OK

func touch(id: String) -> void:
	var config := ConfigFile.new()
	if config.load(_path_for(id)) != OK:
		return
	config.set_value("meta", "last_played", int(Time.get_unix_time_from_system()))
	config.save(_path_for(id))

func sanitize_name(raw_name: String, trim := true) -> String:
	var clean := ""
	for character: String in raw_name.to_upper():
		if character.is_valid_identifier() or character == " " or character.is_valid_int():
			clean += character
	return (clean.strip_edges() if trim else clean).substr(0, MAX_NAME_LENGTH)

func format_timestamp(unix_time: int) -> String:
	if unix_time <= 0:
		return "NEVER"
	var elapsed := maxi(0, int(Time.get_unix_time_from_system()) - unix_time)
	if elapsed < 60:
		return "JUST NOW"
	if elapsed < 3600:
		return "%d MIN AGO" % floori(float(elapsed) / 60.0)
	if elapsed < 86400:
		return "%d HR AGO" % floori(float(elapsed) / 3600.0)
	return "%d DAYS AGO" % floori(float(elapsed) / 86400.0)

func _path_for(id: String) -> String:
	return "%s/%s.cfg" % [SAVE_DIR, id]
