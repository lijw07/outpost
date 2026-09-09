extends Node2D
## Outlined 2.5D camp art, placed at its front ground contact with explicit footprints.
const Art := preload("res://scripts/ui/menu_demo_art.gd")
const ATLAS_INDEX := {0:0,3:2,4:1,5:5,6:3,7:4}
const WIDTH := {0:200.0,3:72.0,4:90.0,5:64.0,6:86.0,7:112.0}
var kind := 0
var flame_frame := 0

func footprint() -> Rect2:
	var sizes := {0:Vector2(176,100),3:Vector2(64,38),4:Vector2(64,58),5:Vector2(42,28),6:Vector2(80,76),7:Vector2(92,140)}
	var dimensions: Vector2 = sizes[kind]
	return Rect2(position-Vector2(dimensions.x*0.5,dimensions.y),dimensions)

func art_rect() -> Rect2:
	var texture := Art.frame(ATLAS_INDEX[kind])
	var dimensions := texture.get_size()*(float(WIDTH[kind])/texture.get_width())
	return Rect2(Vector2(-dimensions.x*0.5,-dimensions.y).snapped(Vector2(2,2)),dimensions.snapped(Vector2(2,2)))

func visual_bounds() -> Rect2:
	return Rect2(position+art_rect().position,art_rect().size)

func _draw() -> void:
	var base := footprint()
	base.position -= position
	draw_rect(Rect2(base.position+Vector2(5,base.size.y-9),Vector2(base.size.x,12)),Color(0.04,0.07,0.05,0.3))
	var warmth := Color(1,1,1)
	if kind == 5:
		warmth = Color(1,0.93+0.025*(flame_frame%3),0.88+0.04*(flame_frame%3))
	draw_texture_rect(Art.frame(ATLAS_INDEX[kind]),art_rect(),false,warmth)
