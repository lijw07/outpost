extends Control

const UI = preload("res://scripts/ui/meadow/ui.gd")
const Item = preload("res://scripts/ui/meadow/item_data.gd")
var hud: Control
var coins := 208
var building := false
var selected: StringName = &"dining"
var demo_panel: PanelContainer

func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var background := ColorRect.new()
	background.color = Color("718367")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	hud = preload("res://scenes/ui/meadow/restaurant_hud.tscn").instantiate()
	add_child(hud)
	var sample: Array[Item] = []
	for entry in [["dining","Table",60,"Furniture & walls"], ["chair","Chair",20,"Furniture & walls"], ["stove","Stove",160,"Furniture & walls"], ["counter","Counter",45,"Furniture & walls"], ["fridge","Fridge",120,"Furniture & walls"], ["wall","Wood wall",20,"Furniture & walls"], ["door","Open doorway",45,"Furniture & walls"], ["flowers","Daisies",12,"Plants & garden"], ["tree","Young oak",60,"Plants & garden"]]:
		var item := Item.new()
		item.id = entry[0]
		item.title = entry[1]
		item.price = entry[2]
		item.category = entry[3]
		item.icon = load("res://assets/ui/meadow/thumbnails/%s.png" % entry[0])
		sample.append(item)
	var special := Item.new()
	special.id = &"soup"
	special.title = "Garden soup"
	special.price = 28
	special.category = "Menu example"
	special.icon = preload("res://assets/ui/meadow/icons/soup.svg")
	sample.append(special)
	hud.set_items(sample)
	hud.build_toggled.connect(func(): building = not building; _update())
	hud.item_requested.connect(func(id):
		selected = id
		hud.notice.text = "Selected: %s. Preview only; no game currency spent." % str(id)
		_update())
	var panel := PanelContainer.new()
	demo_panel = panel
	panel.theme = hud.theme
	panel.position = Vector2(20, 170)
	panel.custom_minimum_size.x = 290
	add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.add_child(UI.label("UI PLAYGROUND", &"Heading"))
	column.add_child(UI.label("One kit. Different arrangements.", &"Caption"))
	column.add_child(UI.button("Service view", func(): building = false; _update()))
	column.add_child(UI.button("Bottom catalog", func(): hud.catalog_layout = "Bottom"; building = true; _update()))
	column.add_child(UI.button("Side catalog", func(): hud.catalog_layout = "Sidebar"; building = true; _update()))
	column.add_child(UI.button("Budget: 40 / 208 coins", func(): coins = 40 if coins == 208 else 208; _update()))
	column.add_child(UI.button("Cream / sage theme", func():
		var alternate: Resource = hud.skin.duplicate()
		alternate.paper = Color("dde6ce") if hud.skin.paper == Color("f7eed8") else Color("f7eed8")
		hud.skin = alternate
		hud.theme = alternate.make_theme()
		panel.theme = hud.theme))
	hud.notice.text = "Resize the window. Cards, tickets, and controls share one theme."
	get_window().size_changed.connect(_fit)
	_fit()
	_update()

func _fit() -> void:
	hud.fit_viewport(Vector2(get_window().size))
	demo_panel.scale = hud.scale
	demo_panel.position = Vector2(20, 170) * hud.scale

func _update() -> void:
	hud.set_state({"coins":coins, "served":1, "building":building, "selected":selected})
	hud.set_orders([{"id":1,"title":"TABLE 01","status":"Ready to serve","tone":"Success"}, {"id":2,"title":"TABLE 02","status":"Cooking","tone":"Warning","progress":.65}], 2, 1, 1)
