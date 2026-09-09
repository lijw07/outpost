extends Node2D
## Whole, fixed-size posts/sacks appear at hammer contact; no stretched fence sprites.
const Art := preload("res://scripts/ui/menu_demo_art.gd")
var progress := 0.0
var health := 0.0
var max_health := 180.0
var vertical := false
var sandbags := false
var worker: Node2D

func footprint() -> Rect2:
	return Rect2(position-Vector2(12,40),Vector2(24,80)) if vertical else Rect2(position-Vector2(40,12),Vector2(80,24))

func section_count() -> int:
	return 4 if vertical or sandbags else 6

func built_fraction(amount := -1.0) -> float:
	return float(clampi(floori((progress if amount < 0 else amount)*section_count()),0,section_count()))/section_count()

func collision_bounds(amount := -1.0) -> Rect2:
	var bounds := footprint()
	var fraction := built_fraction(amount)
	if (health <= 0 and amount < 0) or fraction == 0:
		return Rect2()
	if vertical:
		bounds.size.y *= fraction
	else:
		bounds.size.x *= fraction
	return bounds

func _draw() -> void:
	var index := (8 if sandbags else 6)+(1 if vertical else 0)
	var texture := Art.frame(index)
	var dimensions := Vector2(84,84.0*texture.get_height()/texture.get_width())
	if vertical:
		dimensions = Vector2(116.0*texture.get_width()/texture.get_height(),116)
	dimensions = dimensions.snapped(Vector2(2,2))
	var origin := Vector2(-dimensions.x*0.5,40-dimensions.y if vertical else 10-dimensions.y).snapped(Vector2(2,2))
	# A faint foundation and loose timber mark the work site before posts are raised.
	if progress < 1.0:
		var foundation := footprint()
		foundation.position -= position
		draw_rect(foundation,Color(0.12,0.14,0.09,0.22))
		for piece in 3:
			var point := Vector2(-26+piece*20,0) if not vertical else Vector2(0,-25+piece*20)
			draw_rect(Rect2(point,Vector2(14,4)),Color("7c603d"))
	var count := section_count()
	var complete := clampi(floori(progress*count),0,count)
	if complete > 0:
		var fraction := float(complete)/count
		var region := Rect2(Vector2.ZERO,texture.get_size())
		var destination := Rect2(origin,dimensions)
		if vertical:
			region.size.y *= fraction
			destination.size.y *= fraction
		else:
			region.size.x *= fraction
			destination.size.x *= fraction
		draw_texture_rect_region(texture,destination,region)
	if progress < 1.0 or health < max_health:
		var amount := progress if progress < 1.0 else health/max_health
		var bar_y := 48 if vertical else 18
		draw_rect(Rect2(-24,bar_y,48,4),Color("17251e"))
		draw_rect(Rect2(-24,bar_y,floorf(24*amount)*2,4),Color("c6a25b"))
