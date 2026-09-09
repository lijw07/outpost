extends RefCounted
## Registered original artwork shared by camp props and fence construction stages.
static var _frames: Array[AtlasTexture] = []

static func frame(index: int) -> AtlasTexture:
	if _frames.is_empty():
		var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/menu/camp/frames.json"))
		var atlas: Texture2D = load("res://assets/menu/camp/outlined_camp.png")
		for entry: Dictionary in metadata.frames:
			var texture := AtlasTexture.new()
			texture.atlas = atlas
			texture.region = Rect2(entry.region[0],entry.region[1],entry.region[2],entry.region[3])
			texture.filter_clip = true
			_frames.append(texture)
	return _frames[index]
