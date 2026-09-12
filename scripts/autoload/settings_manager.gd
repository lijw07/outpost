extends Node

signal settings_applied
signal display_preview_started

const CONFIG_PATH := "user://settings.cfg"

const RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(640, 360),
	Vector2i(640, 480),
	Vector2i(800, 600),
	Vector2i(854, 480),
	Vector2i(960, 540),
	Vector2i(1024, 576),
	Vector2i(1024, 768),
	Vector2i(1152, 864),
	Vector2i(1280, 720),
	Vector2i(1280, 800),
	Vector2i(1280, 960),
	Vector2i(1280, 1024),
	Vector2i(1366, 768),
	Vector2i(1400, 1050),
	Vector2i(1440, 900),
	Vector2i(1440, 960),
	Vector2i(1600, 900),
	Vector2i(1600, 1200),
	Vector2i(1680, 1050),
	Vector2i(1920, 1080),
	Vector2i(1920, 1200),
	Vector2i(2048, 1536),
	Vector2i(2160, 1440),
	Vector2i(2560, 1080),
	Vector2i(2560, 1440),
	Vector2i(2560, 1600),
	Vector2i(2560, 1700),
	Vector2i(2880, 1800),
	Vector2i(3000, 2000),
	Vector2i(3200, 1800),
	Vector2i(3440, 1440),
	Vector2i(3840, 1080),
	Vector2i(3840, 1600),
	Vector2i(3840, 2160),
	Vector2i(3840, 2400),
	Vector2i(5120, 1440),
	Vector2i(5120, 2160),
	Vector2i(5120, 2880),
	Vector2i(7680, 4320),
]

const DESIGN_SIZE := Vector2i(1920, 1080)
const MIN_RESOLUTION := Vector2i(640, 360)

const COMMON_ASPECTS := {
	"4:3": 4.0 / 3.0,
	"5:4": 5.0 / 4.0,
	"3:2": 3.0 / 2.0,
	"16:10": 16.0 / 10.0,
	"16:9": 16.0 / 9.0,
	"21:9": 64.0 / 27.0,
	"32:9": 32.0 / 9.0,
}

const AUDIO_BUSES: Array[String] = ["Master", "Music", "SFX"]

const REMAPPABLE_ACTIONS := {
	"move_up": "MOVE UP",
	"move_down": "MOVE DOWN",
	"move_left": "MOVE LEFT",
	"move_right": "MOVE RIGHT",
	"sprint": "SPRINT",
	"interact": "INTERACT",
	"attack": "ATTACK",
	"build_mode": "BUILD MODE",
	"inventory": "INVENTORY",
	"pause": "PAUSE",
}

enum WindowMode { WINDOWED, BORDERLESS, FULLSCREEN }

const DEFAULT_WINDOW_MODE := WindowMode.BORDERLESS

var resolutions: Array[Vector2i] = []
var resolution := Vector2i(1920, 1080)
var window_mode := WindowMode.WINDOWED
var vsync_enabled := true
var reduce_motion := false
var _display_restore := {}
var bus_volumes := {}

var _default_events := {}

func _ready() -> void:
	_capture_default_events()
	rebuild_resolution_list()
	_load_defaults()
	load_settings()
	apply_all()

func rebuild_resolution_list() -> void:
	var screen := DisplayServer.screen_get_size(get_window().current_screen)
	var found: Array[Vector2i] = []
	for preset: Vector2i in RESOLUTION_PRESETS:
		if not found.has(preset):
			found.append(preset)
	if not found.has(screen):
		found.append(screen)
	found.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x * a.y < b.x * b.y if a.x * a.y != b.x * b.y else a.x < b.x)
	resolutions = found

func apply_all() -> void:
	apply_display()
	apply_audio()
	settings_applied.emit()

func apply_display() -> void:
	var window := get_window()
	match window_mode:
		WindowMode.BORDERLESS:
			window.borderless = false
			window.mode = Window.MODE_FULLSCREEN
		WindowMode.FULLSCREEN:
			window.borderless = false
			window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		_:
			window.mode = Window.MODE_WINDOWED
			window.borderless = false
	_apply_resolution()
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)

func apply_audio() -> void:
	for bus_name: String in AUDIO_BUSES:
		var index := AudioServer.get_bus_index(bus_name)
		if index < 0:
			continue
		var linear: float = bus_volumes.get(bus_name, 1.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(linear))
		AudioServer.set_bus_mute(index, linear <= 0.001)

func preview_display(mode: int, size: Vector2i) -> void:
	if _display_restore.is_empty():
		_display_restore = {"mode": int(window_mode), "resolution": resolution}
	window_mode = clampi(mode, 0, 2) as WindowMode
	resolution = size.max(MIN_RESOLUTION)
	apply_display()
	settings_applied.emit()
	display_preview_started.emit()

func confirm_display() -> void:
	_display_restore.clear()
	save_settings()

func revert_display() -> void:
	if _display_restore.is_empty():
		return
	window_mode = int(_display_restore["mode"]) as WindowMode
	resolution = _display_restore["resolution"]
	_display_restore.clear()
	apply_display()
	settings_applied.emit()

func set_reduce_motion(enabled: bool) -> void:
	reduce_motion = enabled
	settings_applied.emit()
	save_settings()

func get_resolution_index() -> int:
	var index := resolutions.find(resolution)
	return index if index >= 0 else 0

func set_vsync(enabled: bool) -> void:
	vsync_enabled = enabled
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	)
	save_settings()

func set_bus_volume(bus_name: String, linear: float) -> void:
	bus_volumes[bus_name] = clampf(linear, 0.0, 1.0)
	apply_audio()
	save_settings()

func get_bus_volume(bus_name: String) -> float:
	return bus_volumes.get(bus_name, 1.0)

func get_binding(action: String) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	var events := InputMap.action_get_events(action)
	return events[0] if not events.is_empty() else null

func binding_conflict(action: String, event: InputEvent) -> String:
	for other: String in REMAPPABLE_ACTIONS:
		if other == action:
			continue
		var existing := get_binding(other)
		if existing != null and existing.is_match(event, false):
			return other
	return ""

func set_binding(action: String, event: InputEvent, swap := false) -> void:
	if not InputMap.has_action(action):
		return
	var old_event := get_binding(action)
	var conflict := binding_conflict(action, event)
	if not conflict.is_empty():
		InputMap.action_erase_events(conflict)
		if swap and old_event != null:
			InputMap.action_add_event(conflict, old_event.duplicate())
	InputMap.action_erase_events(action)
	if event != null:
		InputMap.action_add_event(action, event.duplicate())
	save_settings()
	settings_applied.emit()

func reset_bindings() -> void:
	for action: String in REMAPPABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for event: InputEvent in _default_events.get(action, []):
			InputMap.action_add_event(action, event)
	save_settings()
	settings_applied.emit()

func reset_audio() -> void:
	bus_volumes = {"Master": 0.8, "Music": 0.7, "SFX": 0.8}
	apply_audio()
	save_settings()
	settings_applied.emit()

func reset_display() -> void:
	set_vsync(true)
	set_reduce_motion(false)
	preview_display(DEFAULT_WINDOW_MODE, _default_resolution())

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "window_mode", _display_restore.get("mode", int(window_mode)))
	config.set_value("display", "resolution", _display_restore.get("resolution", resolution))
	config.set_value("display", "vsync", vsync_enabled)
	config.set_value("accessibility", "reduce_motion", reduce_motion)
	for bus_name: String in AUDIO_BUSES:
		config.set_value("audio", bus_name, get_bus_volume(bus_name))
	for action: String in REMAPPABLE_ACTIONS:
		if _is_project_default(action):
			continue
		config.set_value("input", action, "%s>%s" % [
			_default_binding_text(action), serialize_event(get_binding(action))])
	config.save(CONFIG_PATH)

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	window_mode = config.get_value("display", "window_mode", int(window_mode)) as WindowMode
	resolution = config.get_value("display", "resolution", resolution)
	vsync_enabled = config.get_value("display", "vsync", vsync_enabled)
	reduce_motion = config.get_value("accessibility", "reduce_motion", false)
	for bus_name: String in AUDIO_BUSES:
		bus_volumes[bus_name] = config.get_value("audio", bus_name, get_bus_volume(bus_name))
	for action: String in REMAPPABLE_ACTIONS:
		var encoded: String = config.get_value("input", action, "")
		var parts := encoded.split(">")
		if parts.size() != 2 or parts[0] != _default_binding_text(action) or not InputMap.has_action(action):
			continue
		var event := deserialize_event(parts[1])
		if event == null and not parts[1].is_empty():
			continue
		InputMap.action_erase_events(action)
		if event != null:
			InputMap.action_add_event(action, event)

func resolution_label(size: Vector2i) -> String:
	return "%d X %d  (%s)" % [size.x, size.y, aspect_label(size)]

func aspect_label(size: Vector2i) -> String:
	if size.y == 0:
		return "?"
	var ratio := float(size.x) / float(size.y)
	var closest := ""
	var smallest_error := 0.02
	for aspect_name: String in COMMON_ASPECTS:
		var error: float = absf(ratio - COMMON_ASPECTS[aspect_name])
		if error < smallest_error:
			smallest_error = error
			closest = aspect_name
	return closest if not closest.is_empty() else "%.2f:1" % ratio

func serialize_event(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key:%d" % (event as InputEventKey).physical_keycode
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	if event is InputEventJoypadButton:
		return "joy:%d" % (event as InputEventJoypadButton).button_index
	return ""

func deserialize_event(encoded: String) -> InputEvent:
	var parts := encoded.split(":")
	if parts.size() != 2 or not parts[1].is_valid_int():
		return null
	var value := int(parts[1])
	match parts[0]:
		"key":
			var key_event := InputEventKey.new()
			key_event.physical_keycode = value as Key
			return key_event
		"mouse":
			var mouse_event := InputEventMouseButton.new()
			mouse_event.button_index = value as MouseButton
			return mouse_event
		"joy":
			var joy_event := InputEventJoypadButton.new()
			joy_event.button_index = value as JoyButton
			return joy_event
	return null

func event_display_name(event: InputEvent) -> String:
	if event == null:
		return "UNBOUND"
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var keycode := key_event.physical_keycode
		if DisplayServer.get_name() != "headless":
			keycode = DisplayServer.keyboard_get_keycode_from_physical(keycode)
		return OS.get_keycode_string(keycode).to_upper()
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "MOUSE LEFT"
			MOUSE_BUTTON_RIGHT:
				return "MOUSE RIGHT"
			MOUSE_BUTTON_MIDDLE:
				return "MOUSE MIDDLE"
			MOUSE_BUTTON_WHEEL_UP:
				return "WHEEL UP"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "WHEEL DOWN"
			_:
				return "MOUSE %d" % (event as InputEventMouseButton).button_index
	if event is InputEventJoypadButton:
		return "PAD %d" % (event as InputEventJoypadButton).button_index
	return event.as_text().to_upper()

func _apply_resolution() -> void:
	var window := get_window()
	if window_mode != WindowMode.WINDOWED:
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		window.content_scale_size = resolution
		window.content_scale_factor = float(resolution.x) / float(DESIGN_SIZE.x)
		return
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_size = DESIGN_SIZE
	window.content_scale_factor = 1.0
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	if usable.size.x <= 0 or usable.size.y <= 0:
		usable = Rect2i(Vector2i.ZERO, DESIGN_SIZE)
	window.size = resolution.min(usable.size)
	window.position = usable.position + Vector2i(Vector2(usable.size - window.size) / 2.0)

func _default_binding_text(action: String) -> String:
	var events: Array = _default_events.get(action, [])
	return serialize_event(events[0]) if not events.is_empty() else ""

func _is_project_default(action: String) -> bool:
	return serialize_event(get_binding(action)) == _default_binding_text(action)

func _capture_default_events() -> void:
	for action: String in REMAPPABLE_ACTIONS:
		if InputMap.has_action(action):
			_default_events[action] = InputMap.action_get_events(action).duplicate()

func _load_defaults() -> void:
	window_mode = DEFAULT_WINDOW_MODE
	vsync_enabled = true
	resolution = _default_resolution()
	bus_volumes = {"Master": 0.8, "Music": 0.7, "SFX": 0.8}

func _default_resolution() -> Vector2i:
	var native := DisplayServer.screen_get_size(get_window().current_screen)
	if native.x >= MIN_RESOLUTION.x and native.y >= MIN_RESOLUTION.y:
		return native
	return Vector2i(1280, 720)
