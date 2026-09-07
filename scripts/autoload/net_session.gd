extends Node

signal roster_changed
signal status_changed(message: String)

enum Role { OFFLINE, HOSTING, JOINING, CONNECTED }

const MAX_PLAYERS := 4
const DEFAULT_PORT := 27015
const CODE_ALPHABET := "ACDEFGHJKLMNPQRSTUVWXYZ2345679"
const CODE_LENGTH := 6

var role := Role.OFFLINE
var invite_code := ""
var server_name := ""
var port := DEFAULT_PORT
var roster: Array[Dictionary] = []

func host(chosen_name: String, chosen_port: int) -> void:
	server_name = chosen_name
	port = chosen_port
	invite_code = _new_code()
	role = Role.HOSTING
	roster = [_slot(GameSession.character_name, true, true)]
	roster_changed.emit()
	status_changed.emit("HOSTING ON PORT %d" % port)

func join(address: String, chosen_port: int) -> void:
	port = chosen_port
	role = Role.JOINING
	roster = []
	roster_changed.emit()
	status_changed.emit("NO TRANSPORT CONFIGURED - CANNOT REACH %s:%d" % [address, chosen_port])

func leave() -> void:
	role = Role.OFFLINE
	invite_code = ""
	roster = []
	roster_changed.emit()
	status_changed.emit("")

func is_host() -> bool:
	return role == Role.HOSTING

func can_start() -> bool:
	return is_host() and not roster.is_empty()

func open_slots() -> int:
	return MAX_PLAYERS - roster.size()

func _slot(display_name: String, is_owner: bool, ready_state: bool) -> Dictionary:
	var fallback := "PLAYER %d" % (roster.size() + 1)
	return {
		"name": display_name if not display_name.is_empty() else fallback,
		"is_host": is_owner,
		"ready": ready_state,
	}

func _new_code() -> String:
	var generator := RandomNumberGenerator.new()
	generator.randomize()
	var code := ""
	for i in CODE_LENGTH:
		code += CODE_ALPHABET[generator.randi_range(0, CODE_ALPHABET.length() - 1)]
	return code
