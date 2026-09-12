@tool
extends Resource

@export var paper := Color("f7eed8"):
	set(value):
		paper = value
		emit_changed()
@export var ink := Color("243f33"):
	set(value):
		ink = value
		emit_changed()
@export var sage := Color("afbf96"):
	set(value):
		sage = value
		emit_changed()
@export var gold := Color("f4cf68"):
	set(value):
		gold = value
		emit_changed()
@export var border := Color("8b9673"):
	set(value):
		border = value
		emit_changed()
@export var muted := Color("66745c"):
	set(value):
		muted = value
		emit_changed()
@export var warning := Color("e7bc81"):
	set(value):
		warning = value
		emit_changed()
@export var font_size := 16:
	set(value):
		font_size = value
		emit_changed()
@export var spacing := 12:
	set(value):
		spacing = value
		emit_changed()
@export var heading_font: Font = preload("res://assets/ui/font/outpost_pixel.ttf"):
	set(value):
		heading_font = value
		emit_changed()

func box(fill: Color, edge: Color, padding: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.corner_detail = 1
	style.anti_aliasing = false
	style.set_content_margin_all(padding)
	return style

func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = font_size
	for type in ["Label", "Button", "CheckButton", "LineEdit"]:
		result.set_color("font_color", type, ink)
	result.set_stylebox("panel", "PanelContainer", box(paper, border, spacing))
	for type in ["HBoxContainer", "VBoxContainer", "HFlowContainer", "GridContainer"]:
		result.set_constant("separation", type, spacing)
		result.set_constant("h_separation", type, spacing)
		result.set_constant("v_separation", type, spacing)
	for type in ["Button", "PrimaryButton", "QuietButton", "ItemCard"]:
		if type != "Button": result.set_type_variation(type, "Button")
		var fill := gold if type == "PrimaryButton" else paper
		result.set_stylebox("normal", type, box(fill, border))
		result.set_stylebox("hover", type, box(fill.lightened(.08), ink))
		result.set_stylebox("pressed", type, box(gold, ink))
		result.set_stylebox("hover_pressed", type, box(gold.lightened(.1), ink))
		result.set_stylebox("disabled", type, box(paper.darkened(.08), border.lightened(.2)))
		var focus := box(Color.TRANSPARENT, ink, 0)
		focus.set_border_width_all(3)
		focus.expand_margin_left = 3
		focus.expand_margin_top = 3
		focus.expand_margin_right = 3
		focus.expand_margin_bottom = 3
		result.set_stylebox("focus", type, focus)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			result.set_color(state, type, ink)
		result.set_color("font_disabled_color", type, muted)
	result.set_type_variation("Heading", "Label")
	result.set_font("font", "Heading", heading_font)
	result.set_font_size("font_size", "Heading", 20)
	result.set_type_variation("Caption", "Label")
	result.set_font_size("font_size", "Caption", 13)
	result.set_color("font_color", "Caption", muted)
	for state in ["Success", "Warning", "Neutral"]:
		result.set_type_variation(state + "Badge", "PanelContainer")
		var fill := sage if state == "Success" else (warning if state == "Warning" else paper.darkened(.06))
		result.set_stylebox("panel", state + "Badge", box(fill, fill, 6))
	result.set_stylebox("background", "ProgressBar", box(paper.darkened(.15), paper.darkened(.15), 0))
	result.set_stylebox("fill", "ProgressBar", box(gold, gold, 0))
	result.set_stylebox("scroll", "HScrollBar", box(paper.darkened(.08), paper.darkened(.08), 4))
	result.set_stylebox("scroll", "VScrollBar", box(paper.darkened(.08), paper.darkened(.08), 4))
	for type in ["HScrollBar", "VScrollBar"]:
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
			result.set_stylebox(state, type, box(sage, border, 4))
	return result
