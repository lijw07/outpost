@tool
extends Resource

@export var id: StringName:
	set(value):
		id = value
		emit_changed()
@export var title := "Item":
	set(value):
		title = value
		emit_changed()
@export var price := 0:
	set(value):
		price = maxi(0, value)
		emit_changed()
@export var category := "Furniture & walls":
	set(value):
		category = value
		emit_changed()
@export var icon: Texture2D:
	set(value):
		icon = value
		emit_changed()
@export_multiline var description := "":
	set(value):
		description = value
		emit_changed()
@export var footprint := Vector2i.ONE:
	set(value):
		footprint = value
		emit_changed()

func price_text() -> String:
	return "Free" if price == 0 else "%d coins" % price
