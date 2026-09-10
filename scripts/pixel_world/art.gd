@static_unload
extends RefCounted
## Generated art is sampled onto one shared native pixel grid at import/use time.
const ROOT := "res://assets/pixel_world/"
const PIXEL := 1.0/16.0
static var catalog: Dictionary = {}
static var cache: Dictionary = {}
static func frame(sheet: String, index: int) -> Texture2D:
	if catalog.is_empty():
		catalog = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"atlas.json"))
	var key := sheet+str(index)
	if cache.has(key):
		return cache[key]
	var entry: Dictionary = catalog[sheet].frames[index]
	var source: Texture2D = load(ROOT+catalog[sheet].path)
	var region: Array = entry.region
	var image := source.get_image().get_region(Rect2i(region[0],region[1],region[2],region[3]))
	image.resize(entry.size[0],entry.size[1],Image.INTERPOLATE_NEAREST)
	cache[key] = ImageTexture.create_from_image(image)
	return cache[key]

static func sprite(texture: Texture2D) -> Sprite3D:
	var result := Sprite3D.new()
	result.texture = texture
	result.pixel_size = PIXEL
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	result.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	result.alpha_scissor_threshold = 0.5
	result.shaded = true
	result.double_sided = true
	return result

static func tile(color: Color, seed_value: int, planks := false) -> Texture2D:
	var image := Image.create(16,16,false,Image.FORMAT_RGBA8)
	image.fill(color)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in (8 if planks else 7):
		var at := Vector2i(rng.randi_range(0,13),rng.randi_range(0,13))
		image.fill_rect(Rect2i(at,Vector2i(rng.randi_range(1,3),1)),color.lightened(0.08) if index%2 else color.darkened(0.08))
	if planks:
		for y in [0,5,10,15]:
			image.fill_rect(Rect2i(0,y,16,1),color.darkened(0.35))
	return ImageTexture.create_from_image(image)
