@tool
extends Control

signal build_toggled
signal item_requested(id: StringName)

const UI = preload("res://scripts/ui/meadow/ui.gd")
const Card = preload("res://scripts/ui/meadow/item_card.gd")
const Badge = preload("res://scripts/ui/meadow/badge.gd")
const Ticket = preload("res://scripts/ui/meadow/order_ticket.gd")
const ItemData = preload("res://scripts/ui/meadow/item_data.gd")
const MeadowSkin = preload("res://scripts/ui/meadow/skin.gd")

@export var skin: MeadowSkin = preload("res://assets/ui/meadow/default_skin.tres"):
	set(value):
		if skin != null and skin.changed.is_connected(_refresh_theme): skin.changed.disconnect(_refresh_theme)
		skin = value if value != null else preload("res://assets/ui/meadow/default_skin.tres")
		skin.changed.connect(_refresh_theme)
		if is_node_ready(): _refresh_theme()
@export var game_title := "MEADOW & MAIN"
@export var restaurant_name := "THE LITTLE TABLE"
@export_enum("Bottom", "Sidebar", "Auto") var catalog_layout := "Bottom":
	set(value):
		catalog_layout = value
		if is_node_ready(): _layout()
@export var items: Array[ItemData] = []

var build_button: Button
var drawer: PanelContainer
var notice: Label
var help_label: Label
var stats: Label
var top: BoxContainer
var brand: PanelContainer
var wallet: PanelContainer
var service_badge: PanelContainer
var order_panel: PanelContainer
var order_list: VBoxContainer
var order_heading: Label
var order_count: Label
var staff_label: Label
var empty_label: Label
var order_scroll: ScrollContainer
var footer: BoxContainer
var toast: PanelContainer
var camera_hint: Label
var catalog_scroll: ScrollContainer
var cards_grid: GridContainer
var category_bar: HFlowContainer
var drawer_header: BoxContainer
var drawer_actions: HFlowContainer
var drawer_title: Label
var finish_button: Button
var cards: Dictionary = {}
var tickets: Dictionary = {}
var categories: Dictionary = {}
var category := ""
var selected_id: StringName
var balance := 0
var building := false
var _layout_queued := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_theme()
	if not skin.changed.is_connected(_refresh_theme): skin.changed.connect(_refresh_theme)
	_build_header()
	_build_orders()
	_build_catalog()
	_build_footer()
	resized.connect(_queue_layout)
	set_items(items)
	_layout()

func _refresh_theme() -> void:
	theme = skin.make_theme()
	if is_node_ready(): _queue_layout()

func fit_viewport(extent: Vector2) -> void:
	var factor := maxf(1.0, minf(extent.x / 1440.0, extent.y / 900.0))
	if extent.x < 960 or extent.y < 600: factor = minf(extent.x / 960.0, extent.y / 600.0)
	factor = maxf(.1, factor)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	scale = Vector2.ONE * factor
	size = extent / factor

func _panel(parent: Node) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	return panel

func _build_header() -> void:
	top = BoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	brand = _panel(top)
	var brand_row := HBoxContainer.new()
	brand.add_child(brand_row)
	brand_row.add_child(UI.icon(preload("res://assets/ui/meadow/icons/soup.svg"), 40))
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 4)
	brand_row.add_child(copy)
	copy.add_child(UI.label(game_title, &"Heading"))
	copy.add_child(UI.label(restaurant_name, &"Caption"))
	top.add_child(UI.spacer())
	wallet = _panel(top)
	var wallet_row := HBoxContainer.new()
	wallet.add_child(wallet_row)
	wallet_row.add_child(UI.icon(preload("res://assets/ui/meadow/icons/coin.svg"), 26))
	stats = UI.label("0 coins   /   0 served")
	wallet_row.add_child(stats)
	service_badge = Badge.new()
	service_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wallet_row.add_child(service_badge)

func _build_orders() -> void:
	order_panel = _panel(self)
	var column := VBoxContainer.new()
	order_panel.add_child(column)
	var heading_row := HBoxContainer.new()
	column.add_child(heading_row)
	order_heading = UI.label("At the tables", &"Heading")
	order_heading.add_theme_font_size_override("font_size", 16)
	heading_row.add_child(order_heading)
	heading_row.add_child(UI.spacer())
	order_count = UI.label("0 / 0", &"Caption")
	heading_row.add_child(order_count)
	order_scroll = ScrollContainer.new()
	order_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	order_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(order_scroll)
	order_list = VBoxContainer.new()
	order_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	order_scroll.add_child(order_list)
	empty_label = UI.label("Your next guests are on their way.", &"Caption")
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	order_list.add_child(empty_label)
	staff_label = UI.label("", &"Caption")
	column.add_child(staff_label)

func _build_catalog() -> void:
	drawer = _panel(self)
	drawer.visible = false
	var column := VBoxContainer.new()
	drawer.add_child(column)
	drawer_header = BoxContainer.new()
	column.add_child(drawer_header)
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 4)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_header.add_child(copy)
	drawer_title = UI.label("Build & decorate", &"Heading")
	copy.add_child(drawer_title)
	copy.add_child(UI.label("Service is paused while you build.", &"Caption"))
	drawer_actions = HFlowContainer.new()
	drawer_header.add_child(drawer_actions)
	var reclaim := UI.button("Reclaim · 75% back", func(): item_requested.emit(&"erase"))
	reclaim.name = "Reclaim"
	drawer_actions.add_child(reclaim)
	finish_button = UI.button("Finish building  [B]", func(): build_toggled.emit(), &"PrimaryButton")
	finish_button.name = "FinishBuilding"
	drawer_actions.add_child(finish_button)
	category_bar = HFlowContainer.new()
	column.add_child(category_bar)
	catalog_scroll = ScrollContainer.new()
	catalog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(catalog_scroll)
	cards_grid = GridContainer.new()
	catalog_scroll.add_child(cards_grid)
	help_label = UI.label("Click: place  ·  R: rotate  ·  Right click: finish", &"Caption")
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help_label)

func _build_footer() -> void:
	footer = BoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)
	build_button = UI.button("Build & decorate  [B]", func(): build_toggled.emit(), &"PrimaryButton")
	build_button.name = "BuildToggle"
	footer.add_child(build_button)
	toast = _panel(footer)
	toast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notice = UI.label("", &"Caption")
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.add_child(notice)
	camera_hint = UI.label("WASD  Pan   ·   Wheel  Zoom   ·   Home  Center", &"Caption")
	camera_hint.add_theme_color_override("font_color", Color("f7eed8"))
	camera_hint.add_theme_color_override("font_shadow_color", Color("243f33"))
	camera_hint.add_theme_constant_override("shadow_offset_x", 1)
	camera_hint.add_theme_constant_override("shadow_offset_y", 1)
	add_child(camera_hint)

func set_items(value: Array[ItemData]) -> void:
	items = value
	if cards_grid == null: return
	for child in cards_grid.get_children(): child.free()
	for child in category_bar.get_children(): child.free()
	cards.clear()
	categories.clear()
	for item in items:
		if item == null or cards.has(item.id): continue
		if not categories.has(item.category):
			var tab := UI.button(item.category, _select_category.bind(item.category))
			tab.toggle_mode = true
			category_bar.add_child(tab)
			categories[item.category] = tab
		var card := Card.new()
		card.name = "Build_" + str(item.id)
		card.item = item
		card.item_requested.connect(func(id): item_requested.emit(id))
		cards_grid.add_child(card)
		cards[item.id] = card
	var floor_button := UI.button("Floor finish · Free", func(): item_requested.emit(&"floor"))
	floor_button.name = "FloorFinish"
	category_bar.add_child(floor_button)
	if not categories.has(category): category = "" if categories.is_empty() else str(categories.keys()[0])
	_select_category(category)

func _select_category(value: String) -> void:
	category = value
	for key in categories: categories[key].set_pressed_no_signal(key == category)
	for card in cards.values(): card.visible = card.item.category == category
	catalog_scroll.scroll_horizontal = 0
	catalog_scroll.scroll_vertical = 0
	_queue_layout()

func set_state(data: Dictionary) -> void:
	var changed := building != bool(data.get("building", false))
	building = bool(data.get("building", false))
	balance = int(data.get("coins", 0))
	selected_id = StringName(data.get("selected", ""))
	stats.text = "%d coins   /   %d served" % [balance, int(data.get("served", 0))]
	service_badge.text = "SERVICE PAUSED" if building else ("SERVICE OPEN" if data.get("open", true) else "ARRIVALS CLOSED")
	service_badge.tone = "Neutral" if building or not data.get("open", true) else "Success"
	drawer.visible = building
	order_panel.visible = not building
	build_button.text = "Finish building  [B]" if building else "Build & decorate  [B]"
	toast.visible = not notice.text.is_empty()
	for card in cards.values(): card.set_state(balance, selected_id)
	if changed:
		_layout()
		_settle_layout()

func _settle_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_inside_tree(): _layout()

func set_orders(orders: Array, capacity: int, chefs: int, waiters: int) -> void:
	var previous_count := tickets.size()
	order_count.text = "%d / %d" % [orders.size(), capacity]
	staff_label.text = "%d chef%s · %d waiter%s" % [chefs, "" if chefs == 1 else "s", waiters, "" if waiters == 1 else "s"]
	empty_label.visible = orders.is_empty()
	var active := {}
	for data in orders:
		var id = data.id
		active[id] = true
		if not tickets.has(id):
			var ticket := Ticket.new()
			order_list.add_child(ticket)
			tickets[id] = ticket
		tickets[id].configure(data)
	for id in tickets.keys():
		if not active.has(id):
			tickets[id].free()
			tickets.erase(id)
	if tickets.size() != previous_count: _queue_layout()

func _queue_layout() -> void:
	if _layout_queued: return
	_layout_queued = true
	call_deferred("_layout")

func _place(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.size = rect.size

func _layout() -> void:
	_layout_queued = false
	if footer == null or size.x < 1: return
	var narrow := size.x < 800
	var short := size.y < 620
	var side := (catalog_layout == "Sidebar" or catalog_layout == "Auto") and size.x >= 1200
	var pad := 12.0 if narrow else 20.0
	var header_height := 140.0 if narrow else 76.0
	top.vertical = narrow
	top.get_child(1).visible = not narrow
	_place(top, Rect2(pad, pad, size.x - pad * 2, header_height))
	footer.vertical = narrow
	var footer_width := minf(720, size.x - pad * 2)
	var footer_height := 88.0 if narrow else 48.0
	_place(footer, Rect2(pad, size.y - pad - footer_height, footer_width, footer_height))
	camera_hint.visible = not narrow and not short and not building
	_place(camera_hint, Rect2(size.x - 410, size.y - 44, 390, 24))
	var order_width := 292.0 if not narrow else 260.0
	var order_height := minf(90 + maxi(1, tickets.size()) * 155, minf(420, maxf(160, size.y - header_height - footer_height - pad * 4)))
	_place(order_panel, Rect2(size.x - pad - order_width, header_height + pad * 2, order_width, order_height))
	drawer_header.vertical = side or narrow
	drawer_actions.custom_minimum_size.x = 0 if side or narrow else 365
	finish_button.visible = true
	var count := 0
	for card in cards.values():
		if card.visible: count += 1
		card.compact = short and not side
	if side:
		cards_grid.columns = 2
		catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		catalog_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_place(drawer, Rect2(size.x - 388 - pad, header_height + pad * 2, 388, size.y - header_height - pad * 3))
		footer.visible = false
	else:
		cards_grid.columns = maxi(1, count)
		catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		catalog_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		var drawer_height := 322.0 if not short else 248.0
		if narrow: drawer_height += 38
		_place(drawer, Rect2(pad, size.y - pad - drawer_height, size.x - pad * 2, drawer_height))
		footer.visible = not building
	if not building: footer.visible = true
