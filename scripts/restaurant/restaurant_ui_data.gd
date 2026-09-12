extends RefCounted

const Item = preload("res://scripts/ui/meadow/item_data.gd")
const NATURE := ["flowers", "lavender", "fern", "grass", "tall_grass", "shrub", "tree", "plant"]

static func catalog(source: Dictionary) -> Array[Item]:
	var result: Array[Item] = []
	var keys: Array = source.keys()
	keys.erase("dining")
	keys.erase("chair")
	keys.push_front("chair")
	keys.push_front("dining")
	for id in keys:
		if not source.has(id): continue
		var data: Dictionary = source[id]
		var item := Item.new()
		item.id = StringName(id)
		item.title = data.title
		item.price = data.cost
		item.footprint = data.size
		if id == "chair": item.description = "Place beside a table and rotate to face it."
		elif id == "dining": item.description = "Chairs are purchased separately."
		item.category = "Plants & garden" if id in NATURE else "Furniture & walls"
		var path := "res://assets/ui/meadow/thumbnails/%s.png" % id
		if ResourceLoader.exists(path): item.icon = load(path)
		result.append(item)
	return result

static func orders(customers: Array, objects: Array) -> Array:
	var tables := {}
	for item in objects:
		if item.kind == "dining": tables[item.id] = tables.size() + 1
	var result := []
	var titles := {"entering":"Arriving", "waiting":"Order taken", "cooking":"Cooking", "ready":"Ready to serve", "serving":"On its way", "eating":"Enjoying their meal"}
	for guest in customers:
		if guest.state == "leaving": continue
		var ticket := {"id":guest.id, "title":"TABLE %02d" % tables.get(guest.table, 0), "dish":"Garden soup", "status":titles.get(guest.state, "Waiting"), "tone":"Success"}
		if guest.state in ["entering", "waiting"]: ticket.tone = "Neutral"
		if guest.state == "cooking":
			ticket.tone = "Warning"
			ticket["progress"] = 1.0 - clampf(float(guest.timer) / 5.5, 0, 1)
		result.append(ticket)
	return result
