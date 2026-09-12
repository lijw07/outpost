@tool
extends Node3D

@export var building_title := "Building"
@export var floor_count := 1
@export var floor_height := 4.0
@export var interior_preview := false:
	set(value):
		interior_preview = value
		if is_inside_tree():
			_apply_cutaway()
@export_range(0, 20) var preview_floor := 0:
	set(value):
		preview_floor = value
		if is_inside_tree():
			_apply_cutaway()
var occupied_floor := -1
var _doors: Array[Node3D] = []

func _ready() -> void:
	for node in find_children("*", "Node3D", true, false):
		if node.get_meta("building_door", false):
			_doors.append(node)
	_apply_cutaway()

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var next_floor := -1
	for body in $InteriorArea.get_overlapping_bodies():
		if body is CharacterBody3D and (body.name == "Player" or body.is_in_group("player")):
			next_floor = clampi(int(floor((to_local(body.global_position).y + 0.3) / floor_height)), 0, floor_count - 1)
			break
	if occupied_floor != next_floor:
		occupied_floor = next_floor
		_apply_cutaway()

func _apply_cutaway() -> void:
	var active := preview_floor if interior_preview else occupied_floor
	var roof := get_node_or_null("Roof") as Node3D
	if roof != null:
		roof.visible = active < 0
	var floors := get_node_or_null("Floors")
	if floors != null:
		for level in floors.get_children():
			level.visible = active < 0 or level.get_index() <= active

func toggle_nearest_door(point: Vector3, reach: float = 2.5) -> bool:
	var nearest: Node3D
	var distance := reach
	for door in _doors:
		var candidate := door.global_position.distance_to(point)
		if candidate < distance:
			nearest = door
			distance = candidate
	if nearest == null:
		return false
	set_door_open(nearest, not nearest.get_meta("open", false))
	return true

func set_door_open(door: Node3D, open: bool) -> void:
	door.set_meta("open", open)
	door.get_node("Hinge").rotation.y = PI / 2 if open else 0.0

func set_all_doors_open(open: bool) -> void:
	for door in _doors:
		set_door_open(door, open)
