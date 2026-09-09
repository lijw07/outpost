extends Sprite2D
## Nonblocking ground decoration. Animation advances only with the menu simulation.
var asset_name := "grass_short"
var animated := true
var bend := 0.0
var _phase := 0.0
var _contact := 0.0
var _motion: ShaderMaterial
var _used: Rect2i
static var _assets: Dictionary={}
func setup(name_value: String, at: Vector2) -> void:
	asset_name=name_value
	position=at.snapped(Vector2(2,2))
	if not _assets.has(asset_name):
		var source: Texture2D=load("res://assets/environment/meadow/props/"+asset_name+".png")
		_assets[asset_name]={"texture":source,"used":source.get_image().get_used_rect()}
	texture=_assets[asset_name].texture
	_used=_assets[asset_name].used
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	centered=false
	offset=(-Vector2(_used.position)-Vector2(_used.size.x*0.5,_used.size.y)).snapped(Vector2(2,2))
	animated=asset_name in ["grass_short","grass_tall","clover","fern","flowers_white","flowers_yellow"]
	_phase=fposmod(position.x*.017+position.y*.031,TAU)
	if animated:
		_motion=ShaderMaterial.new()
		_motion.shader=preload("res://assets/shaders/menu_foliage.gdshader")
		_motion.set_shader_parameter("rest_texture",texture)
		_motion.set_shader_parameter("sprite_size",texture.get_size())
		_motion.set_shader_parameter("sprite_origin",offset)
		material=_motion
func visual_bounds() -> Rect2:
	return Rect2(position+offset+Vector2(_used.position),Vector2(_used.size))
func advance(delta: float, clock: float, actors: Array[Node2D]) -> void:
	if not animated:return
	var contact_target:=0.0
	for actor in actors:
		if actor.health>0 and actor.position.distance_squared_to(position)<24.0*24.0:
			contact_target=5.0 if actor.position.x<=position.x else -5.0
			break
	_contact=lerpf(_contact,contact_target,1.0-exp(-delta*9.0))
	bend=(sin(clock*1.8+_phase)*0.8+sin(clock*3.1+_phase*.7)*0.2)*3.0+_contact
	_motion.set_shader_parameter("bend",bend)
