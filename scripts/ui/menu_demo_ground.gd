extends Node2D
## Native meadow tiles, with matching corner transitions around the camp clearing.
var variant := 0
var _tiles: Array[Dictionary] = []
var _debris: Array[Vector2] = []

func _ready() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/meadow/manifest.json"))
	var corners := {}
	for entry: Dictionary in manifest.assets:
		if entry.has("corners") and not corners.has(int(entry.corners)):
			corners[int(entry.corners)] = load("res://"+entry.path)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1887+variant*217
	for y in range(-1,18):
		for x in range(-1,31):
			var mask := 0
			for corner in 4:
				var point := Vector2(x+corner%2,y+(corner >> 1))*64
				var distance := (point-Vector2(1320,590))/Vector2(465,390)
				if distance.length() > 1.0:
					mask |= 1 << corner
			_tiles.append({"point":Vector2(x*64,y*64),"texture":corners[mask]})
	for index in 140:
		_debris.append(Vector2(rng.randi_range(0,960)*2,rng.randi_range(0,540)*2))

func _draw() -> void:
	for tile in _tiles:
		draw_texture(tile.texture,tile.point)
	if variant == 1:
		draw_rect(Rect2(0,794,1920,224),Color("626354"))
		draw_rect(Rect2(0,804,1920,204),Color("444e49"))
		draw_rect(Rect2(0,822,1920,4),Color("8e947d"))
		draw_rect(Rect2(0,986,1920,4),Color("8e947d"))
		for x in range(0,1920,140):
			draw_rect(Rect2(x,902,66,4),Color("b1a66a"))
		for point in _debris:
			if point.y > 824 and point.y < 984:
				draw_rect(Rect2(point,Vector2(16,2)),Color("354139"))
				draw_rect(Rect2(point+Vector2(14,2),Vector2(2,8)),Color("354139"))
	if variant == 2:
		for lower in [false,true]:
			var edge := 960 if lower else 0
			var depth := 120 if lower else 220
			draw_rect(Rect2(0,edge,1920,depth),Color("345a59"))
			for x in range(0,1920,32):
				var bank := 8+posmod(x*7,5)*2
				var y := 960-bank if lower else 220
				draw_rect(Rect2(x,y,32,bank),Color("78784f"))
				draw_rect(Rect2(x,y+(0 if lower else bank-4),32,4),Color("89905b"))
			for point in _debris:
				if point.y >= edge+12 and point.y < edge+depth-14:
					draw_rect(Rect2(point,Vector2(24,2)),Color("527671"))
