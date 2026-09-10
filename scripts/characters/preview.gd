extends Control
const Composer := preload("res://scripts/characters/compositor.gd")
const Appearance := preload("res://scripts/characters/appearance.gd")
var profile := Appearance.defaults()
var equipment := {}
var facing := 0
func _ready() -> void:
	custom_minimum_size = Vector2(336,350)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
func _draw() -> void:
	var scale_pixels := floorf(minf(size.x/(Composer.CANVAS.x+12.0),size.y/(Composer.CANVAS.y+12.0)))
	var bounds := Rect2(((size-Vector2(Composer.CANVAS)*scale_pixels)/2).floor(),Vector2(Composer.CANVAS)*scale_pixels)
	draw_texture_rect(Composer.texture(profile,facing,0,equipment),bounds,false)
func refresh(value: Dictionary) -> void:
	profile = value.duplicate(true)
	queue_redraw()
