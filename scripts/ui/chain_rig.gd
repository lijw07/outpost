extends Control

signal hoisted

const CHAIN_TEXTURE := preload("res://assets/ui/props/chains/chain_tile.png")
const SPLATTERS: Array[Texture2D] = [
	preload("res://assets/ui/decals/blood_splatter_01.png"),
	preload("res://assets/ui/decals/blood_splatter_02.png"),
	preload("res://assets/ui/decals/blood_splatter_03.png"),
	preload("res://assets/ui/decals/blood_splatter_04.png"),
	preload("res://assets/ui/decals/blood_splatter_05.png"),
	preload("res://assets/ui/decals/blood_splatter_06.png"),
	preload("res://assets/ui/decals/blood_splatter_07.png"),
	preload("res://assets/ui/decals/blood_splatter_08.png"),
	preload("res://assets/ui/decals/blood_splatter_09.png"),
	preload("res://assets/ui/decals/blood_splatter_10.png"),
	preload("res://assets/ui/decals/blood_splatter_11.png"),
	preload("res://assets/ui/decals/blood_splatter_12.png"),
]
const SPLATTER_COUNT := 6
const SCROLLBAR_KEEPOUT := 76.0
const LIST_SHARE := 0.55
const CHAIN_INSET := 98.0
const CHAIN_CEILING := -90.0
const CHAIN_TILE := 50.0
const CHAIN_LINKS := 56
const CHAIN_BOW := 26.0
const CHAIN_LAG := 0.34
const MOUNT_HALF_WIDTH := 65.0
const PLATE_BITE := 18.0
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
@onready var _chains: Node2D = %Chains
@onready var _splatters: Node2D = %Splatters
@onready var _mount_left: TextureRect = %MountLeft
@onready var _mount_right: TextureRect = %MountRight

var _clear_height := 1500.0
var _hoisting := false
var _angle := 0.0
var _spin := 0.0
var _sag := 0.0
var _fall := 0.0
var _chain_x := 0.0
var _chain_count := 1
var _laid_out := false
var _mount_local := Vector2.ZERO
var _scroll_host: ScrollContainer = null
var _scroll_layer: Node2D = null
var _link_pool: Array[Array] = [[], []]

func _ready() -> void:
	_heading_label.text = heading_text
	_heading_label.theme_type_variation = &"TitleLabel" if use_title_font else &"HeadingLabel"
	_subtitle_label.text = subtitle_text
	_subtitle_label.visible = not subtitle_text.is_empty()
	_build_links()
	_build_splatters()
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
	UiAudio.play_hoist()

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

	_apply_transform()
	if not _hoisting and _is_at_rest():
		_come_to_rest()

func _apply_transform() -> void:
	_rig.rotation = _angle
	_rig.position.y = _sag
	_lay_chains()
	_follow_scroll()

func _follow_scroll() -> void:
	if _scroll_layer != null and _scroll_host != null:
		_scroll_layer.position.y = -_scroll_host.scroll_vertical

func _build_links() -> void:
	for side in 2:
		for i in CHAIN_LINKS:
			var link := Sprite2D.new()
			link.texture = CHAIN_TEXTURE
			link.hide()
			_chains.add_child(link)
			_link_pool[side].append(link)

func _lay_chains() -> void:
	if not _laid_out:
		return
	var centre := size.x * 0.5
	for side in 2:
		var facing := -1.0 if side == 0 else 1.0
		var ceiling := Vector2(centre + facing * _chain_x, CHAIN_CEILING)
		var local := Vector2(facing * _mount_local.x, _mount_local.y)
		var mount := Vector2(centre, _sag) + local.rotated(_angle)
		_lay_chain(_link_pool[side], ceiling, mount)

func _lay_chain(links: Array, ceiling: Vector2, mount: Vector2) -> void:
	var span := mount - ceiling
	var direction := span / maxf(span.length(), 0.001)
	var perpendicular := Vector2(-direction.y, direction.x)
	var bow := clampf(_spin * CHAIN_BOW, -CHAIN_BOW, CHAIN_BOW)
	var angle := direction.angle() - PI * 0.5
	var used := _chain_count
	if _sag < -1.0:
		used = clampi(floori((mount.y - ceiling.y) / CHAIN_TILE), 0, _chain_count)
	for index in links.size():
		var link: Sprite2D = links[index]
		if index >= used:
			link.hide()
			continue
		var travel: float = (float(index) + 0.5) / float(_chain_count)
		var sway := sin(travel * PI) * bow * (1.0 - travel * CHAIN_LAG)
		link.position = ceiling + direction * ((float(index) + 0.5) * CHAIN_TILE) + perpendicular * sway
		link.rotation = angle
		link.show()

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

func _relayout() -> void:
	var half := plate_width * 0.5
	var chain_x := half - CHAIN_INSET
	var wanted: float = body_height if body_height > 0.0 else _plate.get_combined_minimum_size().y
	var plate_height: float = minf(wanted, size.y - top_margin * 2.0)
	var plate_top: float = maxf(top_margin, (size.y - plate_height) * 0.5)
	var plate_bottom := plate_top + plate_height
	_set_rect(_plate, -half, plate_top, half, plate_bottom)

	_chain_x = chain_x
	_mount_local = Vector2(chain_x, plate_top + PLATE_BITE)
	var rest_run := _mount_local.y - CHAIN_CEILING
	_chain_count = clampi(ceili(rest_run / CHAIN_TILE) + 1, 1, CHAIN_LINKS)
	_set_rect(_mount_left, -chain_x - MOUNT_HALF_WIDTH, plate_top - 38.0, -chain_x + MOUNT_HALF_WIDTH, plate_top + 56.0)
	_set_rect(_mount_right, chain_x - MOUNT_HALF_WIDTH, plate_top - 38.0, chain_x + MOUNT_HALF_WIDTH, plate_top + 56.0)

	_clear_height = plate_bottom + CLEAR_MARGIN
	_scatter_blood(half, plate_top, plate_bottom)
	_laid_out = true

func _build_splatters() -> void:
	for i in SPLATTER_COUNT:
		var decal := Sprite2D.new()
		_splatters.add_child(decal)

func _scatter_blood(half: float, plate_top: float, plate_bottom: float) -> void:
	_bind_scroll_layer()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(heading_text)
	var viewport := _scroll_viewport()
	for decal: Sprite2D in _all_decals():
		decal.texture = SPLATTERS[rng.randi() % SPLATTERS.size()]
		decal.rotation = rng.randf_range(0.0, TAU)
		decal.scale = Vector2.ONE * rng.randf_range(0.4, 0.85)
		decal.modulate.a = rng.randf_range(0.5, 0.9)
		decal.flip_h = rng.randf() < 0.5
		var reach := _reach(decal)
		if _list_has_room(viewport, reach) and rng.randf() < LIST_SHARE:
			_ride(decal, _list_spot(rng, viewport, reach))
		else:
			_pin(decal, _frame_spot(rng, half, plate_top, plate_bottom, viewport, reach))
	_follow_scroll()

func _reach(decal: Sprite2D) -> float:
	return decal.texture.get_size().length() * 0.5 * decal.scale.x

func _list_has_room(viewport: Rect2, reach: float) -> bool:
	return _scroll_layer != null \
		and viewport.size.x - SCROLLBAR_KEEPOUT > reach * 2.0 \
		and _content_height() > reach * 2.0

func _content_height() -> float:
	return maxf(_scroll_host.get_v_scroll_bar().max_value, _scroll_host.size.y)

func _list_spot(rng: RandomNumberGenerator, viewport: Rect2, reach: float) -> Vector2:
	var left := viewport.position.x + reach
	var right := viewport.end.x - SCROLLBAR_KEEPOUT - reach
	return Vector2(rng.randf_range(left, maxf(left, right)),
		rng.randf_range(reach, _content_height() - reach))

func _frame_spot(rng: RandomNumberGenerator, half: float, plate_top: float,
		plate_bottom: float, viewport: Rect2, reach: float) -> Vector2:
	var right_limit: float = half - SCROLLBAR_KEEPOUT if _scroll_layer != null else half
	var left := -half + reach
	var right := right_limit - reach
	var x := rng.randf_range(left, maxf(left, right))
	var top_band := Vector2(plate_top + reach,
		(viewport.position.y if viewport.size.y > 0.0 else plate_bottom) - reach)
	var bottom_band := Vector2(
		(viewport.end.y if viewport.size.y > 0.0 else plate_top) + reach, plate_bottom - reach)
	var bands: Array[Vector2] = []
	if top_band.y > top_band.x:
		bands.append(top_band)
	if bottom_band.y > bottom_band.x:
		bands.append(bottom_band)
	if bands.is_empty():
		return Vector2(x, (plate_top + plate_bottom) * 0.5)
	var band: Vector2 = bands[rng.randi() % bands.size()]
	return Vector2(x, rng.randf_range(band.x, band.y))

func _ride(decal: Sprite2D, spot: Vector2) -> void:
	_adopt_decal(decal, _scroll_layer)
	decal.position = Vector2(spot.x - _scroll_viewport().position.x, spot.y)

func _pin(decal: Sprite2D, spot: Vector2) -> void:
	_adopt_decal(decal, _splatters)
	decal.position = spot

func _adopt_decal(decal: Sprite2D, host: Node2D) -> void:
	if decal.get_parent() == host:
		return
	decal.get_parent().remove_child(decal)
	host.add_child(decal)

func _all_decals() -> Array[Sprite2D]:
	var decals: Array[Sprite2D] = []
	for node in _splatters.get_children():
		decals.append(node as Sprite2D)
	if _scroll_layer != null:
		for node in _scroll_layer.get_children():
			decals.append(node as Sprite2D)
	return decals

func _bind_scroll_layer() -> void:
	_scroll_host = _find_scroll()
	if _scroll_host == null:
		_scroll_layer = null
		return
	if not _scroll_host.resized.is_connected(_on_scroll_resized):
		_scroll_host.resized.connect(_on_scroll_resized)
	if _scroll_layer != null and _scroll_layer.get_parent() == _scroll_host:
		return
	_scroll_layer = Node2D.new()
	_scroll_layer.name = "Splatters"
	_scroll_host.add_child(_scroll_layer)
	var bar := _scroll_host.get_v_scroll_bar()
	if not bar.value_changed.is_connected(_on_scroll_moved):
		bar.value_changed.connect(_on_scroll_moved)

func _on_scroll_moved(_value: float) -> void:
	_follow_scroll()

func _on_scroll_resized() -> void:
	_relayout.call_deferred()

func _find_scroll() -> ScrollContainer:
	for node in _content.find_children("*", "ScrollContainer", true, false):
		var scroll := node as ScrollContainer
		if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			return scroll
	return null

func _scroll_viewport() -> Rect2:
	if _scroll_host == null:
		return Rect2()
	var to_rig := _rig.get_global_transform().affine_inverse()
	return Rect2(to_rig * _scroll_host.get_global_transform().origin, _scroll_host.size)

func _set_rect(node: Control, left: float, top: float, right: float, bottom: float) -> void:
	node.offset_left = left
	node.offset_top = top
	node.offset_right = right
	node.offset_bottom = bottom

func _on_visibility_changed() -> void:
	set_physics_process(is_visible_in_tree())
	if is_visible_in_tree():
		_relayout()
		_drop()

func _drop() -> void:
	_hoisting = false
	_sag = -_clear_height
	_fall = 0.0
	_angle = -0.02
	_spin = 0.0
	_apply_transform()
	UiAudio.play_rattle()
