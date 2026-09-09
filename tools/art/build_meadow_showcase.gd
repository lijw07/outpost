extends SceneTree
const PACK := "res://assets/environment/meadow/"
var scene: Node2D
var assets: Array
var placed := 0

func _initialize() -> void:
	assets=JSON.parse_string(FileAccess.get_file_as_string(PACK+"manifest.json"))["assets"]
	scene=Node2D.new()
	scene.name="MeadowShowcase"
	scene.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	scene.set_script(load("res://scripts/environment/meadow_showcase.gd"))
	var bg:=Polygon2D.new()
	bg.name="Backdrop"
	bg.polygon=PackedVector2Array([Vector2.ZERO,Vector2(3840,0),Vector2(3840,1640),Vector2(0,1640)])
	bg.color=Color("25312f")
	_add(bg,scene)
	_label("MEADOW / ALL ARTWORK",Vector2(64,28),46,scene)
	_label("Individual sprites at a shared scale. Click plants to test their movement.",Vector2(64,88),26,scene)
	var ground:=_section("GroundTiles","01  GRASS AND SOIL",Vector2(64,172))
	_grid(ground,["terrain"],8,224,218,108)
	var transitions:=_section("Transitions","02  GRASS / DIRT TRANSITIONS",Vector2(64,764))
	_grid(transitions,["transitions"],8,224,218,108)
	var paths:=_section("Paths","03  PATH PIECES",Vector2(1984,172))
	_grid(paths,["paths"],8,224,218,108)
	var props:=_section("GrassAndProps","04  GRASS, FLOWERS, ROCKS AND PROPS",Vector2(1984,764))
	_grid(props,["grass","props","harvested"],8,224,208,80)
	var camera:=Camera2D.new()
	camera.name="Camera2D"
	camera.position=Vector2(1920,720)
	camera.zoom=Vector2.ONE*0.48
	_add(camera,scene)
	var hud:=CanvasLayer.new()
	hud.name="ViewingControls"
	_add(hud,scene)
	var band:=ColorRect.new()
	band.name="ControlBackground"
	band.color=Color(0.06,0.09,0.08,0.94)
	band.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	band.offset_bottom=66
	band.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_add(band,hud)
	_label("MEADOW SHOWCASE    |    Drag / WASD: pan    |    Wheel: zoom    |    1: native size    |    Space: overview    |    R: reset",Vector2(24,20),20,hud)
	assert(placed==assets.size())
	var packed:=PackedScene.new()
	assert(packed.pack(scene)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/environment/meadow_showcase.tscn")==OK)
	print("PASS: saved 80 individually placed terrain and plant/prop sprites in MeadowShowcase.")
	scene.free()
	quit()

func _add(node: Node,parent: Node) -> void:
	parent.add_child(node)
	node.owner=scene

func _label(text: String,position: Vector2,font_size: int,parent: Node) -> void:
	var label:=Label.new()
	label.text=text
	label.position=position
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("e6e2c8"))
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_add(label,parent)

func _section(name: String,title: String,position: Vector2) -> Node2D:
	var section:=Node2D.new()
	section.name=name
	section.position=position
	_add(section,scene)
	_label(title,Vector2.ZERO,34,section)
	return section

func _grid(parent: Node2D,kinds: Array,columns: int,width: float,height: float,top: float) -> void:
	var index:=0
	for asset: Dictionary in assets:
		if not asset["kind"] in kinds: continue
		var base:=Vector2((index%columns)*width+width/2.0,top+floori(index/float(columns))*height+106)
		_place(asset,base,parent)
		_label(asset["name"],Vector2(base.x-width/2.0+4,base.y+14),18,parent)
		index+=1

func _place(asset: Dictionary,position: Vector2,parent: Node2D) -> void:
	var name: String=asset["name"]
	var art: Node2D
	if FileAccess.file_exists(PACK+"animations/"+name+".tres"):
		var animated:=AnimatedSprite2D.new()
		animated.sprite_frames=load(PACK+"animations/"+name+".tres")
		animated.animation=&"wind"
		animated.autoplay="wind"
		animated.centered=false
		animated.offset=Vector2(-float(asset["size"][0])/2.0,-float(asset["size"][1])+4)
		if asset.get("reactive",false): animated.set_script(load("res://scripts/environment/meadow_plant.gd"))
		art=animated
	else:
		var sprite:=Sprite2D.new()
		sprite.texture=load("res://"+asset["path"])
		sprite.centered=false
		sprite.offset=Vector2(-float(asset["size"][0])/2.0,-float(asset["size"][1])+4)
		art=sprite
	art.name=name
	art.position=position
	art.scale=Vector2(2,2)
	art.set_meta("asset_name",name)
	art.set_meta("hit_rect",Rect2(-float(asset["size"][0])/2.0,-float(asset["size"][1])+4,float(asset["size"][0]),float(asset["size"][1])))
	art.add_to_group("showcase_assets",true)
	_add(art,parent)
	placed+=1
