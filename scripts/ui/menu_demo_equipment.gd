extends RefCounted
## Data and source atlases are independent of the menu AI for future reuse.
const ROOT := "res://assets/menu/equipment/"
static var outfits: Array = []
static var weapons: Array = []
static var firearms: Array = []
static var atlases: Dictionary = {}

static func prepare() -> void:
	if not outfits.is_empty():
		return
	outfits = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"outfits.json"))
	weapons = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"weapons.json"))
	firearms = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"firearms.json"))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"frames.json"))
	for category: String in data:
		var source: Texture2D = load(ROOT+data[category].path)
		var frames: Array[AtlasTexture] = []
		for entry: Dictionary in data[category].frames:
			var texture := AtlasTexture.new()
			texture.atlas = source
			texture.region = Rect2(entry.region[0],entry.region[1],entry.region[2],entry.region[3])
			frames.append(texture)
		atlases[category] = frames

static func frame(category: String, index: int) -> AtlasTexture:
	prepare()
	return atlases[category][index]
