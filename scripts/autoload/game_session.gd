extends Node

const MAX_PLAYERS := 4
const SHOW_LOADING_SCREEN := false
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
	pending_scene = GAME_SCENE
	if SHOW_LOADING_SCREEN:
		get_tree().change_scene_to_file(LOADING_SCENE)
		return
	get_tree().change_scene_to_file(GAME_SCENE)

func return_to_menu() -> void:
	pending_scene = ""
	get_tree().change_scene_to_file(MENU_SCENE)
