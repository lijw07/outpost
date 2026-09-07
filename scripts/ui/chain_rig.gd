extends Control

signal hoisted

const CHAIN_INSET := 98.0
const CHAIN_HALF_WIDTH := 22.0
const CHAIN_TOP := -1700.0
const CHAIN_TILE := 50.0
const MOUNT_HALF_WIDTH := 65.0
const PLATE_BITE := 18.0
const DRIP_SOURCE_Y := 10.0
const CLEAR_MARGIN := 220.0

const FALL_GRAVITY := 2600.0
const CHAIN_STIFFNESS := 1600.0
const CHAIN_DAMPING := 44.0
const SWING := 3.1
const SWING_DAMP := 0.85
const CATCH_SPEED := 700.0
const REST_ANGLE := 0.0004
const REST_SPIN := 0.0008
const REST_SAG := 0.05
const REST_FALL := 0.6
const HOIST_ACCEL := 9000.0
const HOIST_KICK := 260.0

const BEAD_START := -90.0
const BEAD_SPEED_MIN := 45.0
const BEAD_SPEED_MAX := 80.0
const BEAD_WAIT_MIN := 1.5
const BEAD_WAIT_MAX := 6.5

@export var heading_text := "OUTPOST"
@export var subtitle_text := ""
@export var use_title_font := false
@export var plate_width := 840.0
@export var body_height := 440.0
@export var top_margin := 60.0

@onready var _rig: Control = %Rig
@onready var _plate: PanelContainer = %Plate
@onready var _content: VBoxContainer = %Content
@onready var _heading_label: Label = %HeadingLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _chain_left: TextureRect = %ChainLeft
@onready var _chain_right: TextureRect = %ChainRight
@onready var _mount_left: TextureRect = %MountLeft
@onready var _mount_right: TextureRect = %MountRight
@onready var _beads: Array[Sprite2D] = [%BeadLeft, %BeadRight]
@onready var _bead_drips: Array[AnimatedSprite2D] = [%DripChainA, %DripChainB]
@onready var _drips: Array[AnimatedSprite2D] = [%DripA, %DripB, %DripC, %DripD]

var _clear_height := 1500.0
var _hoisting := false
var _angle := 0.0
var _spin := 0.0
var _sag := 0.0
var _fall := 0.0
var _bead_end := 0.0
var _bead_travel: Array[float] = [0.0, 0.0]
var _bead_speed: Array[float] = [0.0, 0.0]
var _bead_wait: Array[float] = [0.0, 0.0]

func _ready() -> void:
	_heading_label.text = heading_text
	_heading_label.theme_type_variation = &"TitleLabel" if use_title_font else &"HeadingLabel"
	_subtitle_label.text = subtitle_text
	_subtitle_label.visible = not subtitle_text.is_empty()
	_stagger_drips()
	for drip: AnimatedSprite2D in _bead_drips:
		drip.animation_looped.connect(drip.hide)
	_bead_wait[0] = randf_range(0.4, 2.0)
	_bead_wait[1] = randf_range(2.0, 5.0)
	resized.connect(_relayout)
	visibility_changed.connect(_on_visibility_changed)
	set_physics_process(false)
	_relayout.call_deferred()

func adopt(node: Control) -> void:
	var previous := node.get_parent()
	if previous != null:
		previous.remove_child(node)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(node)
	_relayout.call_deferred()

func hoist() -> void:
	if _hoisting:
		return
	if not is_visible_in_tree():
		hoisted.emit.call_deferred()
		return
	_hoisting = true
	_fall -= HOIST_KICK
	_spin += randf_range(-0.08, 0.08)
	UiAudio.play_rattle(1.18)

func _physics_process(delta: float) -> void:
	_spin += (-SWING * sin(_angle) - SWING_DAMP * _spin) * delta
	_angle += _spin * delta

	var was_slack := _sag < 0.0
	if _hoisting:
		_fall -= HOIST_ACCEL * delta
	else:
		_fall += _chain_force(_sag, _fall) * delta
	_sag += _fall * delta
	if _hoisting and _sag <= -_clear_height:
		_hoisting = false
		hoisted.emit()
	if not _hoisting and was_slack and _sag >= 0.0 and _fall > CATCH_SPEED:
		UiAudio.play_back()
		_spin += randf_range(-0.15, 0.15)

	_run_beads(delta)

	_apply_transform()
	if not _hoisting and _is_at_rest():
		_come_to_rest()

func _apply_transform() -> void:
	_rig.rotation = _angle
	_rig.position.y = _sag


func _is_at_rest() -> bool:
	return absf(_angle) < REST_ANGLE and absf(_spin) < REST_SPIN \
		and absf(_sag) < REST_SAG and absf(_fall) < REST_FALL

func _come_to_rest() -> void:
	_angle = 0.0
	_spin = 0.0
	_sag = 0.0
	_fall = 0.0
	_apply_transform()

func _chain_force(stretch: float, speed: float) -> float:
	var pull := stretch + FALL_GRAVITY / CHAIN_STIFFNESS
	if pull < 0.0:
		return FALL_GRAVITY
	return FALL_GRAVITY - CHAIN_STIFFNESS * pull - CHAIN_DAMPING * speed

func _run_beads(delta: float) -> void:
	for index in _beads.size():
		if _bead_wait[index] > 0.0:
			_bead_wait[index] -= delta
			if _bead_wait[index] <= 0.0:
				_launch_bead(index)
			continue
		_bead_travel[index] += _bead_speed[index] * delta
		_beads[index].position.y = _bead_travel[index]
		if _bead_travel[index] < _bead_end:
			continue
		_beads[index].hide()
		_bead_wait[index] = randf_range(BEAD_WAIT_MIN, BEAD_WAIT_MAX)
		var drip := _bead_drips[index]
		drip.show()
		drip.frame = 0
		drip.play()

func _launch_bead(index: int) -> void:
	_bead_wait[index] = 0.0
	_bead_travel[index] = BEAD_START
	_bead_speed[index] = randf_range(BEAD_SPEED_MIN, BEAD_SPEED_MAX)
	_beads[index].position.y = BEAD_START
	_beads[index].show()

func _stagger_drips() -> void:
	for drip: AnimatedSprite2D in _drips:
		drip.speed_scale = randf_range(0.72, 1.28)
		drip.frame = randi() % drip.sprite_frames.get_frame_count(drip.animation)

func _relayout() -> void:
	var half := plate_width * 0.5
	var chain_x := half - CHAIN_INSET
	var wanted: float = maxf(_plate.get_combined_minimum_size().y, body_height)
	var plate_height: float = minf(wanted, size.y - top_margin * 2.0)
	var plate_top: float = maxf(top_margin, (size.y - plate_height) * 0.5)
	var plate_bottom := plate_top + plate_height
	_set_rect(_plate, -half, plate_top, half, plate_bottom)

	var chain_bottom := plate_top + PLATE_BITE
	var chain_top := chain_bottom - _tiled_height(chain_bottom - CHAIN_TOP)
	_set_rect(_chain_left, -chain_x - CHAIN_HALF_WIDTH, chain_top, -chain_x + CHAIN_HALF_WIDTH, chain_bottom)
	_set_rect(_chain_right, chain_x - CHAIN_HALF_WIDTH, chain_top, chain_x + CHAIN_HALF_WIDTH, chain_bottom)
	_set_rect(_mount_left, -chain_x - MOUNT_HALF_WIDTH, plate_top - 38.0, -chain_x + MOUNT_HALF_WIDTH, plate_top + 56.0)
	_set_rect(_mount_right, chain_x - MOUNT_HALF_WIDTH, plate_top - 38.0, chain_x + MOUNT_HALF_WIDTH, plate_top + 56.0)

	_clear_height = plate_bottom + CLEAR_MARGIN
	_bead_end = plate_top + 6.0
	_beads[0].position.x = -chain_x
	_beads[1].position.x = chain_x
	_place_drip(_bead_drips[0], Vector2(-chain_x, plate_top + 12.0))
	_place_drip(_bead_drips[1], Vector2(chain_x, plate_top + 12.0))
	_place_drip(_drips[0], Vector2(-half * 0.34, plate_top + 24.0))
	_place_drip(_drips[1], Vector2(half * 0.52, plate_top + 18.0))
	_place_drip(_drips[2], Vector2(-half * 0.62, plate_bottom - 8.0))
	_place_drip(_drips[3], Vector2(half * 0.26, plate_bottom - 4.0))

func _place_drip(drip: AnimatedSprite2D, anchor: Vector2) -> void:
	var frame_height := drip.sprite_frames.get_frame_texture(drip.animation, 0).get_size().y
	drip.position = anchor + Vector2(0.0, (frame_height * 0.5 - DRIP_SOURCE_Y) * drip.scale.y)

func _tiled_height(wanted: float) -> float:
	return ceilf(wanted / CHAIN_TILE) * CHAIN_TILE

func _set_rect(node: Control, left: float, top: float, right: float, bottom: float) -> void:
	node.offset_left = left
	node.offset_top = top
	node.offset_right = right
	node.offset_bottom = bottom

func _on_visibility_changed() -> void:
	set_physics_process(is_visible_in_tree())
	if is_visible_in_tree():
		_drop()

func _drop() -> void:
	_hoisting = false
	_sag = -_clear_height
	_fall = 0.0
	_angle = -0.02
	_spin = 0.0
	_apply_transform()
	UiAudio.play_rattle()
