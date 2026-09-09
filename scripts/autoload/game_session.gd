extends Node

const MAX_PLAYERS := 4
const LAST_SESSION_PATH := "user://last_session.cfg"
const SHOW_LOADING_SCREEN := true
const LOADING_SCENE := "res://scenes/ui/loading_screen.tscn"
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const GAME_SCENE := "res://scenes/world/game.tscn"

var is_coop := false
var character_name := ""
var save_id := ""
var world_id := ""
var world_name := ""
var world_seed := 0
var pending_scene := ""

func start_game() -> void:
	if not is_coop and not save_id.is_empty() and not world_id.is_empty():
		var last := ConfigFile.new()
		last.set_value("session", "survivor", save_id)
		last.set_value("session", "world", world_id)
		last.save(LAST_SESSION_PATH)
		SaveManager.touch(save_id)
		WorldManager.touch(world_id)
	pending_scene = GAME_SCENE
	if SHOW_LOADING_SCREEN:
		get_tree().change_scene_to_file(LOADING_SCENE)
		return
	get_tree().change_scene_to_file(GAME_SCENE)

func return_to_menu() -> void:
	get_tree().paused = false
	NetSession.leave()
	pending_scene = ""
	get_tree().change_scene_to_file(MENU_SCENE)

func last_session() -> Dictionary:
	var last := ConfigFile.new()
	if last.load(LAST_SESSION_PATH) != OK:
		return {}
	var survivor := SaveManager.read_save(last.get_value("session", "survivor", ""))
	var world := WorldManager.read_world(last.get_value("session", "world", ""))
	if survivor.is_empty() or world.is_empty():
		return {}
	return {"survivor": survivor, "world": world}

func restore_last_session() -> bool:
	var last := last_session()
	if last.is_empty():
		return false
	NetSession.leave()
	is_coop = false
	save_id = last.survivor.id
	character_name = last.survivor.character_name
	world_id = last.world.id
	world_name = last.world.world_name
	world_seed = last.world.seed
	return true
