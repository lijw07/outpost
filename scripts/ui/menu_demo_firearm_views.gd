extends RefCounted
## Small outlined plan-view weapons for vertical aim; side art remains authored.
static var textures: Dictionary = {}

static func top_view(id: String) -> Texture2D:
	if textures.has(id):
		return textures[id]
	var image := Image.create(48,16,false,Image.FORMAT_RGBA8)
	var ink := Color("14211f")
	var metal := Color("46534e")
	var light := Color("879187")
	var furniture := Color("71694b") if id in ["scar","ak","assault_rifle"] else Color("303a35")
	# Local X points toward the muzzle. The silhouette has no side-view magazine.
	image.fill_rect(Rect2i(1,4,12,8),ink)
	image.fill_rect(Rect2i(2,5,10,6),furniture)
	image.fill_rect(Rect2i(11,3,21,10),ink)
	image.fill_rect(Rect2i(12,4,18,8),metal)
	image.fill_rect(Rect2i(13,5,17,2),light)
	image.fill_rect(Rect2i(13,8,17,3),Color("283730"))
	image.fill_rect(Rect2i(30,5,15,6),ink)
	image.fill_rect(Rect2i(31,6,14,3),metal)
	image.fill_rect(Rect2i(32,6,12,1),light)
	image.fill_rect(Rect2i(44,5,3,6),ink)
	for x in [24,27,30]:
		image.fill_rect(Rect2i(x,4,1,8),ink)
	if id in ["sniper","dmr"]:
		image.fill_rect(Rect2i(14,5,14,6),ink)
		image.fill_rect(Rect2i(15,6,12,3),light)
	if id in ["rocket_launcher","grenade_launcher"]:
		image.fill_rect(Rect2i(3,2,42,12),ink)
		image.fill_rect(Rect2i(4,3,40,10),Color("576342"))
		image.fill_rect(Rect2i(5,4,38,2),Color("88906b"))
	if id == "pistol":
		image.fill(Color.TRANSPARENT)
		image.fill_rect(Rect2i(8,3,37,10),ink)
		image.fill_rect(Rect2i(9,4,35,8),metal)
		image.fill_rect(Rect2i(13,5,29,2),light)
		image.fill_rect(Rect2i(42,6,3,4),ink)
	var texture := ImageTexture.create_from_image(image)
	textures[id] = texture
	return texture
