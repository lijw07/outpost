@tool
extends PanelContainer

@export var text := "Service open":
	set(value):
		text = value
		if is_node_ready(): $Text.text = text
@export_enum("Success", "Warning", "Neutral") var tone := "Success":
	set(value):
		tone = value
		theme_type_variation = StringName(tone + "Badge")

func _ready() -> void:
	theme_type_variation = StringName(tone + "Badge")
	var label := Label.new()
	label.name = "Text"
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
