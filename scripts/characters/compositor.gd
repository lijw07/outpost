@static_unload
extends RefCounted
const Appearance := preload("res://scripts/characters/appearance.gd")
const ROOT := "res://assets/characters/modular/"
const DETAIL := 3
const CANVAS := Vector2i(24,32)*DETAIL
static var _atlas: Dictionary = {}
static var _layers: Dictionary = {}
static var _frames: Dictionary = {}

static func texture(profile: Dictionary, facing: int, stride := 0, worn: Dictionary = {}) -> Texture2D:
	var key := JSON.stringify([profile,facing,stride,worn])
	if not _frames.has(key):
		if _frames.size() >= 256:
			_frames.clear()
		_frames[key] = ImageTexture.create_from_image(compose(profile,facing,stride,worn))
	return _frames[key]

static func layer(sheet: String, index: int, tint: Color, skin_only := false) -> Image:
	if _atlas.is_empty():
		_atlas = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"atlas.json"))
	var key := "%s:%d:%s:%s" % [sheet,index,tint.to_html(),skin_only]
	if _layers.has(key):
		return _layers[key]
	var entry: Dictionary = _atlas[sheet].frames[index]
	var source: Texture2D = load(ROOT+_atlas[sheet].path)
	var bounds: Array = entry.region
	var pixels := source.get_image().get_region(Rect2i(bounds[0],bounds[1],bounds[2],bounds[3]))
	pixels.resize(entry.size[0]*DETAIL,entry.size[1]*DETAIL,Image.INTERPOLATE_NEAREST)
	for y in pixels.get_height():
		for x in pixels.get_width():
			var ink := pixels.get_pixel(x,y)
			if ink.a < 0.7:
				pixels.set_pixel(x,y,Color.TRANSPARENT)
				continue
			var gray := (ink.r+ink.g+ink.b)/3
			if gray < 0.16:
				ink = Color("222b2a")
			elif not skin_only or maxf(ink.r,maxf(ink.g,ink.b))-minf(ink.r,minf(ink.g,ink.b)) < 0.10:
				var shade := clampf(gray / (0.72 if skin_only else 0.58),0.20,1.25)
				ink = Color(tint.r*shade,tint.g*shade,tint.b*shade,1)
			ink.a = 1
			pixels.set_pixel(x,y,ink)
	if _layers.size() >= 512:
		_layers.clear()
	_layers[key] = pixels
	return pixels

static func _draw(target: Image, sheet: String, index: int, tint: Color, skin_only := false) -> void:
	var pixels := layer(sheet,index,tint,skin_only)
	var entry: Dictionary = _atlas[sheet].frames[index]
	target.blend_rect(pixels,Rect2i(Vector2i.ZERO,pixels.get_size()),Vector2i(entry.at[0],entry.at[1])*DETAIL)

static func compose(raw_profile: Dictionary, facing: int, stride := 0, raw_equipment: Dictionary = {}) -> Image:
	var profile := Appearance.sanitize(raw_profile)
	var worn := Appearance.equipment(raw_equipment)
	facing = posmod(facing,4)
	var result := Image.create(CANVAS.x,CANVAS.y,false,Image.FORMAT_RGBA8)
	_draw(result,"base",(0 if profile.sex == "male" else 1)*4+facing,Appearance.color(profile.skin,true),true)
	if worn.get("legs") == "cargo_pants" or profile.pants == "jeans":
		_draw(result,"bottoms",(1 if worn.get("legs") == "cargo_pants" else 0)*4+facing,Appearance.color(profile.pants_color))
	else:
		_draw(result,"civilian",(1 if profile.pants == "shorts" else 0)*4+facing,Appearance.color(profile.pants_color))
	if worn.get("feet") == "combat_boots" or profile.shoes == "sneakers":
		_draw(result,"bottoms",(3 if worn.get("feet") == "combat_boots" else 2)*4+facing,Appearance.color(profile.shoes_color))
	else:
		_draw(result,"civilian",(2 if profile.shoes == "high_tops" else 3)*4+facing,Appearance.color(profile.shoes_color))
	var top: int = ["tee","sweatshirt","jacket"].find(profile.top)
	_draw(result,"tops",(3 if worn.get("outer") == "field_jacket" else top)*4+facing,Color("6d7950") if worn.get("outer") == "field_jacket" else Appearance.color(profile.top_color))
	if worn.get("legs") == "ghillie_pants":
		_draw(result,"ghillie",8+facing,Color("778353"))
	if worn.get("outer") == "ghillie_jacket":
		_draw(result,"ghillie",4+facing,Color("778353"))
	if worn.get("armor") == "plate_carrier":
		_draw(result,"gear",12+facing,Color("5b655a"))
	if worn.has("bag"):
		_draw(result,"ghillie" if worn.bag == "rucksack" else "gear",12+facing if worn.bag == "rucksack" else 8+facing,Color("70664a"))
	if profile.hair != "bald" and worn.get("hat") != "ghillie_hood":
		var hair := Image.create(CANVAS.x,CANVAS.y,false,Image.FORMAT_RGBA8)
		_draw(hair,"hair",["crop","bob","ponytail","curls"].find(profile.hair)*4+facing,Appearance.color(profile.hair_color))
		var visible_hair := Rect2i(0,13*DETAIL,CANVAS.x,19*DETAIL) if worn.has("hat") else Rect2i(Vector2i.ZERO,CANVAS)
		result.blend_rect(hair,visible_hair,visible_hair.position)
	var eyes := Appearance.color(profile.eye_color).lightened(0.18)
	if facing == 0:
		_eye(result,9,12,eyes)
		_eye(result,13,12,eyes)
	elif facing in [1,3]:
		_eye(result,14 if facing == 1 else 9,12,eyes)
	if worn.has("hat"):
		if worn.hat == "ghillie_hood":
			_draw(result,"ghillie",facing,Color("778353"))
		else:
			_draw(result,"gear",(4 if worn.hat == "helmet" else 0)+facing,Color("697654") if worn.hat == "helmet" else Appearance.color(profile.top_color))
	if stride in [1,3]:
		var walking := result.duplicate() as Image
		for y in range(24*DETAIL,CANVAS.y):
			for x in CANVAS.x:
				var offset := (1 if x<12*DETAIL else -1)*(1 if stride == 1 else -1)
				var source_y := y+offset*DETAIL
				walking.set_pixel(x,y,result.get_pixel(x,source_y) if source_y>=24*DETAIL and source_y<CANVAS.y else Color.TRANSPARENT)
		for y in range(18*DETAIL,24*DETAIL):
			for x in range(6*DETAIL,18*DETAIL):
				var arm: bool = (x<9*DETAIL or x>=15*DETAIL) if facing in [0,2] else (x>=11*DETAIL and x<15*DETAIL)
				if arm:
					var shift := (1 if x<12*DETAIL else -1)*(1 if stride == 1 else -1)
					walking.set_pixel(x,y,result.get_pixel(x,y+shift*DETAIL))
		return walking
	return result

static func _eye(target: Image, x: int, y: int, color: Color) -> void:
	target.fill_rect(Rect2i(x*DETAIL,y*DETAIL,DETAIL,2*DETAIL),Color("222b2a"))
	target.fill_rect(Rect2i(x*DETAIL,y*DETAIL,DETAIL,DETAIL),color)
