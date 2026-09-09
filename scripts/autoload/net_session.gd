extends Node

signal roster_changed
signal status_changed(message: String)

enum Role { OFFLINE, HOSTING, JOINING, CONNECTED }

const MAX_PLAYERS := 4
const TRANSPORT_AVAILABLE := false
const UNAVAILABLE_MESSAGE := "CO-OP IS COMING SOON - PLAY SINGLE PLAYER FOR NOW"
const DEFAULT_PORT := 27015
const CODE_ALPHABET := "ACDEFGHJKLMNPQRSTUVWXYZ2345679"
const CODE_LENGTH := 6

var role := Role.OFFLINE
var invite_code := ""
var server_name := ""
var port := DEFAULT_PORT
var roster: Array[Dictionary] = []

func seat_local_player() -> void:
	if not roster.is_empty():
		return
	roster = [_slot(GameSession.character_name, true, true)]
	roster_changed.emit()

func host(chosen_name: String, chosen_port: int) -> void:
	if not TRANSPORT_AVAILABLE:
		leave()
		status_changed.emit(UNAVAILABLE_MESSAGE)
		return
	if not valid_port(chosen_port):
		status_changed.emit("PORT MUST BE BETWEEN 1 AND 65535")
		return
	server_name = chosen_name
	port = chosen_port
	invite_code = _new_code()
	role = Role.HOSTING
	seat_local_player()
	roster_changed.emit()
	status_changed.emit("")

func join(address: String, chosen_port: int) -> void:
	var error := join_validation(address, chosen_port)
	if not error.is_empty():
		status_changed.emit(error)
		return
	if not TRANSPORT_AVAILABLE:
		leave()
		status_changed.emit(UNAVAILABLE_MESSAGE)
		return
	port = chosen_port
	role = Role.JOINING
	roster = []
	roster_changed.emit()
	status_changed.emit("CANNOT REACH %s:%d" % [address, chosen_port])

func leave() -> void:
	server_name = ""
	port = DEFAULT_PORT
	role = Role.OFFLINE
	invite_code = ""
	roster = []
	roster_changed.emit()
	status_changed.emit("")

func is_host() -> bool:
	return role == Role.HOSTING

func can_start() -> bool:
	return TRANSPORT_AVAILABLE and is_host() and not roster.is_empty() and not GameSession.world_id.is_empty()

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

func valid_port(value: int) -> bool:
	return value > 0 and value < 65536

func join_validation(address: String, chosen_port: int) -> String:
	if address.strip_edges().is_empty():
		return "ENTER A SERVER ADDRESS"
	if not valid_port(chosen_port):
		return "PORT MUST BE BETWEEN 1 AND 65535"
	return ""
