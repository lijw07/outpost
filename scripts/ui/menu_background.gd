extends Control
## One location per application session, drawn from a persistent shuffled deck.
## Returning from gameplay keeps the location; restarting advances the deck.

const LOCATIONS: Array[String] = [
	"res://scenes/ui/backgrounds/last_watch.tscn",
	"res://scenes/ui/backgrounds/dead_air.tscn",
	"res://scenes/ui/backgrounds/drowned_mile.tscn",
]
const ROTATION_PATH := "user://menu_scenery.cfg"
static var session_location := -1

var location: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if session_location < 0:
		session_location = next_location(ROTATION_PATH)
	show_location(session_location)

func show_location(index: int) -> void:
	if location != null:
		remove_child(location)
		location.queue_free()
	location = load(LOCATIONS[posmod(index, LOCATIONS.size())]).instantiate()
	add_child(location)

static func next_location(path: String) -> int:
	var config := ConfigFile.new()
	var remaining: Array[int] = []
	var previous := -1
	if config.load(path) == OK:
		var saved_last: Variant = config.get_value("rotation", "last", -1)
		if saved_last is int:
			previous = saved_last
		var saved_deck: Variant = config.get_value("rotation", "remaining", [])
		if saved_deck is Array:
			for item: Variant in saved_deck:
				if item is int and item >= 0 and item < LOCATIONS.size() and item != previous and not remaining.has(item):
					remaining.append(item)
	if remaining.is_empty():
		for index in LOCATIONS.size():
			remaining.append(index)
		remaining.shuffle()
		if remaining.back() == previous:
			var first := remaining[0]
			remaining[0] = remaining[-1]
			remaining[-1] = first
	var selected: int = remaining.pop_back()
	config.set_value("rotation", "last", selected)
	config.set_value("rotation", "remaining", remaining)
	# An unwritable preference file must never prevent the menu from opening.
	config.save(path)
	return selected
