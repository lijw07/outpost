extends SceneTree

var checks := 0
var failures: Array[String] = []
var settings: Node
var session: Node
var saves: Node
var worlds: Node
var network: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func settle(frames := 6) -> void:
	for i in frames:
		await process_frame

func action(name: String) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = name
	event.pressed = false
	Input.parse_input_event(event)
	await settle()

func key(value: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = value
	event.pressed = true
	return event

func pointer_motion(control: Control, point: Vector2, dragging := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = control.get_global_transform_with_canvas() * point
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if dragging else 0
	root.push_input(event, true)
	await settle(2)

func pointer_button(control: Control, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = control.get_global_transform_with_canvas() * point
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event, true)
	await settle(2)

func check_slider_edges(panel: Control) -> void:
	for slider_name in ["MasterSlider", "MusicSlider", "SfxSlider"]:
		var slider: HSlider = panel.get_node("%" + slider_name)
		for maximum in [true, false]:
			slider.value = slider.max_value if maximum else slider.min_value
			await settle()
			var overhang := slider.get_theme_icon("grabber").get_width() * 0.5 if slider.get_theme_constant("center_grabber") else 0.0
			# Grab the outer tip of the visible handle, including any part outside the track.
			var tip := Vector2(slider.size.x + overhang - 2.0 if maximum else 2.0 - overhang, slider.size.y * 0.5)
			await pointer_motion(slider, tip)
			check(root.gui_get_hovered_control() == slider, "%s handle tip is hoverable at %s" % [slider_name, "100%" if maximum else "0%"])
			await pointer_button(slider, tip, true)
			await pointer_motion(slider, slider.size * 0.5, true)
			await pointer_button(slider, slider.size * 0.5, false)
			check(slider.value > 40.0 and slider.value < 60.0, "%s can drag away from the endpoint into the middle of the track" % slider_name)

func check_toggles(panel: Control) -> void:
	await settle()
	for control_name in ["VsyncCheck", "ReduceMotionCheck"]:
		var toggle: CheckBox = panel.get_node("%" + control_name)
		for i in 2:
			var previous := toggle.button_pressed
			await pointer_motion(toggle, toggle.size * 0.5)
			check(toggle.is_hovered(), "%s is hoverable when %s" % [control_name, "checked" if previous else "unchecked"])
			await pointer_button(toggle, toggle.size * 0.5, true)
			await pointer_button(toggle, toggle.size * 0.5, false)
			check(toggle.button_pressed != previous, "%s switches on click" % control_name)

func check_revert_hover(panel: Control) -> void:
	var dialog: Control = panel.get_node("%DisplayConfirm")
	var revert: Button = panel.get_node("%RevertButton")
	await pointer_motion(panel, Vector2.ZERO)
	dialog.show()
	await settle()
	check(revert.has_focus() and not revert.has_focus(true), "mouse-opened display dialog keeps Revert as its default without a stuck gold state")
	await pointer_motion(revert, revert.size * 0.5)
	check(revert.is_hovered(), "Revert enters its gold hover state")
	await pointer_motion(panel, Vector2.ZERO)
	check(not revert.is_hovered() and not revert.has_focus(true), "Revert returns to normal when the pointer leaves")
	await action("ui_focus_next")
	check(panel.get_node("%KeepButton").has_focus(true), "keyboard navigation visibly focuses Keep")
	await action("ui_focus_next")
	check(revert.has_focus(true), "keyboard navigation visibly focuses Revert")
	await pointer_button(revert, revert.size * 0.5, true)
	await pointer_button(revert, revert.size * 0.5, false)
	check(not dialog.visible, "Revert remains clickable")

func type_name(panel: Control, value: String) -> void:
	for character in value:
		var text: String = panel._name_field.text + character
		panel._name_field.text = text
		panel._name_field.caret_column = text.length()
		panel._on_name_changed(text)

func run() -> void:
	if not "outpost-ui-checks" in OS.get_user_data_dir().to_lower():
		push_error("Use tests/run_ui_checks.py; this suite only runs in its disposable profile.")
		quit(2)
		return
	settings = root.get_node("Settings")
	session = root.get_node("GameSession")
	saves = root.get_node("SaveManager")
	worlds = root.get_node("WorldManager")
	network = root.get_node("NetSession")
	if "--binding-reload" in OS.get_cmdline_user_args():
		check(settings.get_binding("move_up").physical_keycode == KEY_S, "rebound key survives a fresh process")
		check(settings.get_binding("move_down") == null, "explicit unbound state survives a fresh process")
		check(settings.reduce_motion, "reduce motion survives a fresh process")
		check(not session.last_session().is_empty(), "Continue pair survives a fresh process")
		await finish()
		return
	settings.reduce_motion = true
	settings.window_mode = 0
	settings.resolution = Vector2i(1280, 720)
	settings.apply_all()
	settings.save_settings()
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await settle()
	check(menu._current == menu._title_panel, "launch opens title")
	var music: AudioStreamPlayer = menu.get_node("MenuMusic")
	check(music.playing and music.stream.loop, "menu music starts and loops")
	check(music.bus == &"Music" and absf(music.stream.get_length() - 106.6667) < 0.1, "original menu track loads on the Music bus")
	check(not menu._title_panel.get_node("%ContinueButton").visible, "Continue is hidden without a valid pair")
	await menu._show_panel(menu._settings_panel)
	await settle()
	check(menu.get_node("MenuMusic") == music and music.playing, "menu navigation keeps the same music player running")
	var panel: Control = menu._settings_panel
	check(panel.get_node("%DisplaySection").visible, "Display tab is initially active")
	await check_toggles(panel)
	await check_revert_hover(panel)
	panel._show_section(2)
	await settle()
	check(panel.get_node("%ControlsSection").visible and not panel.get_node("%DisplaySection").visible, "tabs isolate settings sections")
	check(panel._bind_list.get_child_count() == 10, "all ten controls are available")
	for row in panel._bind_list.get_children():
		check(panel.get_node("%Scroll").get_global_rect().encloses(row.get_global_rect()), "control row %s fits area %s (row %s)" % [row._action, panel.get_node("%Scroll").get_global_rect(), row.get_global_rect()])
	panel._on_binding_requested("move_up", key(KEY_S))
	check(panel.get_node("%ConflictConfirm").visible, "conflict asks before replacing another action")
	check(settings.get_binding("move_up").physical_keycode == KEY_W, "opening conflict does not change controls")
	await action("ui_cancel")
	check(not panel.get_node("%ConflictConfirm").visible and menu._current == panel, "Escape cancels only binding dialog")
	panel._on_binding_requested("move_up", key(KEY_S))
	panel._resolve_conflict(true)
	check(settings.get_binding("move_up").physical_keycode == KEY_S and settings.get_binding("move_down").physical_keycode == KEY_W, "Swap preserves both actions")
	settings.reset_bindings()
	panel._show_section(0)
	await settle()
	var dropdown: Control = panel._resolution_option
	var original_index: int = dropdown.selected
	var original_vsync: bool = settings.vsync_enabled
	dropdown._open()
	await action("ui_down")
	check(dropdown._highlighted == (original_index + 1) % dropdown.item_count, "Down highlights a dropdown option")
	await action("ui_accept")
	check(panel._confirm.visible, "Enter selects resolution and opens confirmation")
	check(settings.vsync_enabled == original_vsync, "dropdown keys cannot toggle V-sync behind it")
	var previous: Vector2i = settings._display_restore.resolution
	settings.set_bus_volume("Music", 0.25)
	var config := ConfigFile.new()
	config.load(settings.CONFIG_PATH)
	check(config.get_value("display", "resolution") == previous, "saving audio during preview does not persist unconfirmed display settings")
	await action("ui_cancel")
	check(menu._current == panel and not panel._confirm.visible, "Escape reverts display without leaving Settings")
	check(settings.resolution == previous and settings._display_restore.is_empty(), "display state fully restored")
	settings.preview_display(0, Vector2i(1024, 768))
	await settle()
	var modal: Control = panel._confirm
	for i in 4:
		await action("ui_focus_next")
		check(modal.is_ancestor_of(root.gui_get_focus_owner()), "Tab stays inside display confirmation")
	panel._seconds_left = 1
	panel._on_countdown_tick()
	check(settings.resolution == previous, "display timeout restores previous resolution")
	settings.preview_display(0, Vector2i(1280, 800))
	panel._keep_display()
	config.load(settings.CONFIG_PATH)
	check(config.get_value("display", "resolution") == Vector2i(1280, 800), "Keep saves chosen resolution")
	panel._reset_section()
	check(panel._confirm.visible, "Reset Display uses safety confirmation")
	panel._revert_display()
	settings.set_reduce_motion(true)
	panel._show_section(1)
	await settle()
	await check_slider_edges(panel)
	panel._on_volume_changed(37.0, "Master")
	check(is_equal_approx(settings.get_bus_volume("Master"), 0.37), "audio slider updates the correct bus")
	panel._reset_section()
	check(is_equal_approx(settings.get_bus_volume("Master"), 0.8), "Reset Audio restores defaults")
	await menu._go_back()
	menu._start_game(false)
	await settle()
	var survivor_panel: Control = menu._save_select_panel
	check(menu._current == survivor_panel, "single-player flow opens survivors")
	survivor_panel._show_name_entry()
	type_name(survivor_panel, "QA Survivor")
	check(survivor_panel._name_field.text == "QA SURVIVOR", "spaces survive survivor entry")
	await action("ui_cancel")
	check(not survivor_panel._name_row.visible and menu._current == survivor_panel, "Escape cancels name entry without leaving screen")
	survivor_panel._show_name_entry()
	type_name(survivor_panel, "QA Survivor")
	survivor_panel._create_save()
	await settle()
	check(saves.list_saves().size() == 1, "creating a survivor persists one record")
	var world_panel: Control = menu._world_select_panel
	check(menu._current == world_panel, "survivor creation opens world selection")
	check("QA SURVIVOR" in world_panel.get_node("%SelectionContext").text, "world selection shows chosen survivor")
	world_panel._show_name_entry()
	type_name(world_panel, "QA Meadow")
	check(world_panel._name_field.text == "QA MEADOW", "spaces survive world entry")
	world_panel._create_world()
	for i in 100:
		await create_timer(0.02).timeout
		if current_scene != null and current_scene.scene_file_path == session.GAME_SCENE:
			break
	check(current_scene.scene_file_path == session.GAME_SCENE, "creation, loading, and launch reach the game")
	if current_scene.scene_file_path != session.GAME_SCENE:
		await finish()
		return
	var game := current_scene
	check(not is_instance_valid(music), "menu music is released when gameplay starts")
	check(game.get_node("%WorldHeading").text == "QA MEADOW", "HUD shows chosen world")
	check(not session.last_session().is_empty(), "launch records Continue pair")
	settings.set_binding("pause", key(KEY_P))
	check("P: PAUSE" in game.get_node("%MovementHint").text, "HUD reflects remapped pause key")
	var camera: Camera2D = game.get_node("Camera2D")
	var camera_before := camera.position
	Input.action_press("move_right")
	await create_timer(0.05).timeout
	Input.action_release("move_right")
	check(camera.position.x > camera_before.x, "camera responds to movement")
	await action("pause")
	var pause_menu: Control = game.get_node("%PauseMenu")
	check(paused and pause_menu.visible, "pause action opens pause menu")
	camera_before = camera.position
	Input.action_press("move_right")
	await create_timer(0.05).timeout
	Input.action_release("move_right")
	check(camera.position == camera_before, "camera does not move while paused")
	await pause_menu._show_settings()
	check(paused and pause_menu.get_node("SettingsPanel").visible, "Settings opens while game remains paused")
	var pause_settings: Control = pause_menu.get_node("SettingsPanel")
	await check_toggles(pause_settings)
	await check_revert_hover(pause_settings)
	pause_settings._show_section(1)
	await settle()
	await check_slider_edges(pause_settings)
	await pause_menu._close_settings()
	pause_menu.resume()
	check(not paused and not pause_menu.visible, "Resume restores gameplay")
	session.return_to_menu()
	await settle(12)
	menu = current_scene
	check(menu.get_node("MenuMusic").playing, "returning to the menu starts its music again")
	check(menu.get_node("Screens/TitlePanel/%ContinueButton").visible, "title offers Continue after returning")
	check(session.restore_last_session(), "Continue resolves survivor and world")
	check(session.character_name == "QA SURVIVOR" and session.world_name == "QA MEADOW", "Continue restores the correct pair")
	await menu._show_panel(menu._mode_select_panel)
	menu._start_game(true)
	await settle()
	survivor_panel = menu._save_select_panel
	var survivor: Dictionary = saves.list_saves()[0]
	survivor_panel._ask_delete(survivor)
	await action("ui_cancel")
	check(menu._current == survivor_panel and not survivor_panel._delete_confirm.visible, "Escape cancels survivor deletion only")
	check(saves.list_saves().size() == 1, "cancelled deletion preserves survivor")
	survivor_panel._on_slot_pressed(survivor)
	await settle()
	check(menu._current == menu._lobby_panel, "co-op reaches Host/Join without requiring a world")
	var lobby: Control = menu._lobby_panel
	check(lobby.get_node("%OpenButton").disabled and lobby.get_node("%ConnectButton").disabled and lobby.get_node("%StartButton").disabled, "unavailable networking cannot appear connected")
	check(lobby._address_field.text == "127.0.0.1", "Join uses a real default address")
	check(lobby._status_label.get_parent().name == "Content", "co-op availability notice stays outside scrolling content")
	check(network.join_validation("", 27015) == "ENTER A SERVER ADDRESS", "empty addresses get a useful error")
	check(not network.valid_port(0) and not network.valid_port(65536), "invalid ports are rejected")
	lobby._host_port_field.text = "27abc"
	check(lobby._port_from(lobby._host_port_field) == -1, "non-numeric ports do not silently fall back")
	var history_size: int = menu._history.size()
	menu._choose_lobby_world()
	await settle()
	world_panel = menu._world_select_panel
	world_panel._on_slot_pressed(worlds.list_worlds()[0])
	await settle()
	check(menu._current == lobby and menu._history.size() == history_size, "map selection returns without duplicate Back entries")
	network.role = network.Role.HOSTING
	network.invite_code = "TEST"
	await action("ui_cancel")
	check(menu._current == survivor_panel and network.role == network.Role.OFFLINE and network.invite_code.is_empty(), "Escape leaves and clears lobby state")
	# Exercise the new pagination with full and partially full pages.
	for i in 5:
		saves.create_save("EXTRA%d" % i)
	survivor_panel.refresh()
	check(survivor_panel._slot_list.get_child_count() == 3 and survivor_panel._pager.visible, "six survivors paginate three at a time")
	check(survivor_panel._new_game_button.disabled and "6 / 6" in survivor_panel.get_node("%SlotSummary").text, "full survivor list explains its capacity")
	survivor_panel._turn_page(1)
	check(survivor_panel._slot_list.get_child_count() == 3 and survivor_panel._next_button.disabled, "last survivor page is bounded")
	await menu._show_panel(menu._world_select_panel)
	await settle()
	world_panel = menu._world_select_panel
	var extra_world := {}
	for i in 5:
		extra_world = worlds.create_world("EXTRA WORLD%d" % i)
	world_panel.refresh()
	check(world_panel._new_world_button.disabled and world_panel._pager.visible, "world capacity and pagination match survivors")
	world_panel._turn_page(1)
	await settle()
	check(world_panel._world_list.get_child_count() == 3, "second world page contains the remaining records")
	world_panel._ask_delete(extra_world)
	await action("ui_cancel")
	check(menu._current == world_panel and worlds.list_worlds().size() == 6, "Escape cancels world deletion without navigating away")
	world_panel._ask_delete(extra_world)
	world_panel._confirm_delete()
	await settle()
	check(worlds.list_worlds().size() == 5 and not world_panel._new_world_button.disabled, "confirmed deletion removes only the chosen test world and restores capacity")
	world_panel._show_name_entry()
	await settle()
	check(root.get_visible_rect().encloses(world_panel.get_node("%BackButton").get_global_rect()), "world creation footer remains onscreen with pagination")
	world_panel._cancel_name_entry()
	settings.set_reduce_motion(false)
	await menu._go_back()
	check(menu._current == survivor_panel, "normal animated Back transition finishes")
	settings.set_reduce_motion(true)
	check(survivor_panel.get_node("ChainRig")._angle == 0.0, "Reduce Motion immediately settles an active sign")
	worlds.delete_world(session.world_id)
	check(session.last_session().is_empty(), "deleted world invalidates Continue safely")
	# Leave a real pair and binding conflict for the fresh-process checks.
	var replacement: Dictionary = worlds.create_world("RELOAD WORLD")
	session.world_id = replacement.id
	var last := ConfigFile.new()
	last.set_value("session", "survivor", survivor.id)
	last.set_value("session", "world", replacement.id)
	last.save(session.LAST_SESSION_PATH)
	settings.reset_bindings()
	settings.set_binding("move_up", key(KEY_S))
	check(settings.get_binding("move_down") == null, "Replace explicitly unbinds the conflicting action")
	settings.set_reduce_motion(true)
	await finish()

func finish() -> void:
	print("UI REGRESSION: %d checks, %d failures" % [checks, failures.size()])
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	await settle(3)
	root.get_node("UiAudio").stop_all()
	await create_timer(0.15).timeout
	quit(0 if failures.is_empty() else 1)
