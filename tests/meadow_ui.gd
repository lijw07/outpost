extends SceneTree

var errors: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message)

func frames(count: int = 5) -> void:
	for i in count: await RenderingServer.frame_post_draw

func click(control: Control) -> void:
	await frames()
	var point := control.get_global_transform_with_canvas() * (control.size / 2)
	Input.warp_mouse(point)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(2)

func key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(2)

func capture(name: String) -> void:
	await frames()
	root.get_texture().get_image().save_png("res://output/restaurant_ui_dynamic/%s.png" % name)

func within(control: Control, bounds: Rect2) -> bool:
	return bounds.grow(1).encloses(control.get_global_rect())

func _run() -> void:
	for i in 5: await process_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	var scene = load("res://scenes/world/meadow_preview.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await frames(12)
	scene.set_process(false)
	if scene.camera == null:
		push_error("Restaurant world did not load; UI integration checks cannot run.")
		quit(1)
		return
	for i in 200: scene._tick_service(.1)
	scene._update_ui()
	await capture("service")
	var hud = scene.hud
	check(hud.cards.size() == scene.Model.CATALOG.size(), "Every catalog item gets a reusable card")
	check(hud.tickets.size() > 0, "Live customer orders appear")
	var ticket_ids := []
	for ticket in hud.tickets.values(): ticket_ids.append(ticket.get_instance_id())
	scene._update_ui()
	check(hud.tickets.values()[0].get_instance_id() in ticket_ids, "State updates reuse ticket nodes")
	await click(scene.build_button)
	check(scene.build_mode and hud.drawer.visible, "Mouse opens build catalog")
	await click(hud.cards.dining)
	check(scene.selected == "dining" and hud.cards.dining.button_pressed, "Mouse selects and highlights item")
	await capture("build_bottom")
	check(within(hud.drawer, Rect2(Vector2.ZERO, Vector2(root.size))), "Initial bottom drawer fits after container layout settles")
	var before: int = scene.model.objects.size()
	await click(hud.category_bar)
	check(scene.model.objects.size() == before, "Clicking UI does not place furniture")
	await click(hud.categories["Plants & garden"])
	check(hud.cards.grass.visible and not hud.cards.dining.visible, "Category switches visible data")
	await click(hud.cards.grass)
	check(scene.selected == "grass", "Nature card sends selected item id")
	scene.model.coins = 10
	scene._update_ui()
	check(hud.cards.tree.disabled and not hud.cards.grass.disabled, "Affordability updates from current balance")
	await click(hud.cards.tree)
	check(scene.selected == "grass", "Unaffordable item cannot be selected")
	scene.model.coins = 208
	scene._update_ui()
	await click(hud.categories["Furniture & walls"])
	hud.cards.dining.grab_focus()
	await key(KEY_SPACE)
	check(scene.selected == "dining", "Keyboard can activate focused card")
	await key(KEY_B)
	check(not scene.build_mode, "B closes build mode even after card focus")
	await key(KEY_B)
	hud.catalog_layout = "Sidebar"
	await capture("build_sidebar")
	check(hud.cards_grid.columns == 2 and hud.drawer.visible, "Same cards form a side grid")
	await click(hud.finish_button)
	check(not scene.build_mode, "Side drawer finish button resumes service")
	for dimensions in [Vector2i(1920,1080), Vector2i(1280,720), Vector2i(800,600), Vector2i(640,360), Vector2i(900,1200)]:
		root.size = dimensions
		await frames(8)
		scene._resize_view()
		hud.catalog_layout = "Bottom"
		if not scene.build_mode: scene.toggle_build()
		await frames(8)
		var bounds := Rect2(Vector2.ZERO, Vector2(root.size))
		check(within(hud.drawer, bounds), "Build drawer fits %s" % dimensions)
		check(within(hud.top, bounds), "Header fits %s" % dimensions)
		check(within(hud.footer, bounds), "Footer fits %s" % dimensions)
		check(not hud.drawer.get_global_rect().intersects(hud.top.get_global_rect()), "Drawer does not overlap header at %s" % dimensions)
		await capture("build_%dx%d" % [dimensions.x,dimensions.y])
		scene.toggle_build()
		await frames()
		check(within(hud.order_panel, bounds), "Orders fit %s" % dimensions)
		check(not hud.order_panel.get_global_rect().intersects(hud.footer.get_global_rect()), "Orders do not overlap footer at %s" % dimensions)
		await capture("service_%dx%d" % [dimensions.x,dimensions.y])
	root.size = Vector2i(1440,900)
	await frames()
	scene.queue_free()
	await frames()
	var demo = load("res://scenes/ui/meadow/showcase.tscn").instantiate()
	root.add_child(demo)
	current_scene = demo
	await capture("playground")
	check(demo.hud.categories.has("Menu example"), "Unrelated menu item reuses catalog without restaurant model")
	var dynamic = demo.hud.cards.soup.item
	dynamic.price = 999
	check(demo.hud.cards.soup.disabled, "Resource price edits refresh existing cards")
	dynamic.title = "Seasonal soup"
	check("Seasonal soup" in demo.hud.cards.soup.tooltip_text, "Resource copy edits refresh existing cards")
	var alternate = demo.hud.skin.duplicate()
	demo.hud.skin = alternate
	alternate.ink = Color("314867")
	check(demo.hud.theme.get_color("font_color", "Label") == alternate.ink, "Shared palette edits refresh the live theme")
	var report := {"passed":errors.is_empty(),"checks":checks,"errors":errors}
	FileAccess.open("res://output/restaurant_ui_dynamic/validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MEADOW_UI ", JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
