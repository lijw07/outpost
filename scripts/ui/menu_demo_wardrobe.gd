extends Node2D
## Modular visual attachments follow the same ground pivot as the character.
const FirearmViews := preload("res://scripts/ui/menu_demo_firearm_views.gd")
const Equipment := preload("res://scripts/ui/menu_demo_equipment.gd")
var outfit: Dictionary
var weapon: Dictionary
var firearm: Dictionary
var hat: Sprite2D
var hair: Sprite2D
var ears: Sprite2D
var bag: Sprite2D
var held: Sprite2D

func _sprite(key_background := false) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://assets/shaders/menu_actor_palette.gdshader")
	shader.set_shader_parameter("key_neutral_background",key_background)
	sprite.material = shader
	add_child(sprite)
	return sprite

func setup(outfit_index: int, weapon_index: int) -> void:
	Equipment.prepare()
	outfit = Equipment.outfits[outfit_index%Equipment.outfits.size()]
	weapon = Equipment.weapons[weapon_index%Equipment.weapons.size()]
	firearm = Equipment.firearms[weapon_index%Equipment.firearms.size()]
	bag = _sprite()
	hair = _sprite()
	hat = _sprite(true)
	ears = _sprite()
	held = _sprite()
	held.texture = Equipment.frame(weapon.get("atlas","weapons"),weapon.frame)
	held.centered = false
	held.offset = Vector2(-held.texture.get_width()*0.12,-held.texture.get_height()*0.5)
	held.scale = Vector2.ONE*float(weapon.length)/held.texture.get_width()

func dress(palette: ShaderMaterial) -> void:
	palette.set_shader_parameter("dress_survivor",true)
	for garment in ["jacket","shirt","trousers","shoes","backpack"]:
		palette.set_shader_parameter(garment+"_color",Color(outfit[garment]))
	palette.set_shader_parameter("replace_backpack",int(outfit.bag) != 0)

func _fit(sprite: Sprite2D, texture: Texture2D, at: Vector2, width: float) -> void:
	sprite.texture = texture
	sprite.position = at.snapped(Vector2(2,2))
	sprite.scale = Vector2.ONE*width/texture.get_width()

func update_pose(actor: Node2D) -> void:
	position = actor.render_offset
	modulate = actor.body.modulate
	visible = actor.health > 0
	var direction: int = actor.facing
	var head: Vector2 = actor.head_socket+(actor.pose_shift+actor.moving_recoil)*0.85
	var torso: Vector2 = actor.torso_socket+(actor.pose_shift+actor.moving_recoil)*0.55
	var wears_hat: bool = int(outfit.headgear) >= 0
	hat.visible = wears_hat
	hair.visible = not wears_hat
	if wears_hat:
		var ghillie: bool = int(outfit.headgear) == 4
		hat.material.set_shader_parameter("key_neutral_background",not ghillie)
		var hood_offset := Vector2(-3 if direction == 1 else 3 if direction == 3 else 0,8) if ghillie else Vector2.ZERO
		_fit(hat,Equipment.frame("ghillie",direction) if ghillie else Equipment.frame("headgear",int(outfit.headgear)*4+direction),head+hood_offset,actor.head_width*(1.3 if ghillie else 1.08))
	else:
		_fit(hair,Equipment.frame("hair_bags",int(outfit.hair)*4+direction),head,actor.head_width*1.1)
	ears.visible = outfit.earmuffs
	if ears.visible:
		var earmuff := Equipment.frame("wearables",8+direction)
		_fit(ears,earmuff,head+Vector2(0,1),actor.head_width*1.1*earmuff.get_width()/Equipment.frame("wearables",8).get_width())
	bag.visible = int(outfit.bag) != 0 and direction != 0
	if bag.visible:
		var texture := Equipment.frame("hair_bags" if int(outfit.bag) == 1 else "wearables",12+direction)
		var side := -11.0 if direction == 1 else 11.0 if direction == 3 else 0.0
		var reference := Equipment.frame("hair_bags" if int(outfit.bag) == 1 else "wearables",12)
		_fit(bag,texture,torso+Vector2(side,4 if int(outfit.bag) == 1 else 11),23.0*texture.get_width()/reference.get_width())
	var palette := actor.body.material as ShaderMaterial
	palette.set_shader_parameter("cover_hair",wears_hat)
	palette.set_shader_parameter("carry_pose",actor.current_clip == "carry")
	palette.set_shader_parameter("replace_arms",actor.weapon_kind() != "")
	palette.set_shader_parameter("facing_direction",direction)
	palette.set_shader_parameter("armor_enabled",int(outfit.armor) >= 0)
	if int(outfit.armor) >= 0:
		var armor := Equipment.frame("ghillie",4+direction) if int(outfit.armor) == 2 else Equipment.frame("wearables",int(outfit.armor)*4+direction)
		palette.set_shader_parameter("armor_texture",armor.atlas)
		palette.set_shader_parameter("armor_region",Vector4(armor.region.position.x/armor.atlas.get_width(),armor.region.position.y/armor.atlas.get_height(),armor.region.size.x/armor.atlas.get_width(),armor.region.size.y/armor.atlas.get_height()))
		palette.set_shader_parameter("armor_bounds",Vector4(actor.torso_socket.x-9,actor.torso_socket.y-3,18,23) if direction in [0,2] else Vector4(actor.torso_socket.x-7,actor.torso_socket.y-3,14,23))
	held.visible = visible and (actor.weapon_kind() != "")
	held.modulate = modulate
	if held.get_parent() == actor:
		actor.move_child(held,1 if direction == 2 else actor.get_child_count()-2)
	if actor.weapon_kind() == "melee":
		held.texture = Equipment.frame(weapon.get("atlas","weapons"),weapon.frame)
		held.offset = Vector2(-held.texture.get_width()*0.12,-held.texture.get_height()*0.5)
		held.scale = Vector2.ONE*actor.weapon_scale()/held.texture.get_width()
		held.position = actor.render_offset+actor.weapon_grip()
		held.rotation = actor.weapon_direction().angle()
		held.flip_v = direction in [2,3]
		held.show_behind_parent = false
	elif actor.weapon_kind() == "firearm":
		held.texture = FirearmViews.top_view(firearm.id) if direction in [0,2] else Equipment.frame(firearm.get("atlas","firearms"),firearm.frame)
		held.offset = Vector2(-held.texture.get_width()*0.32,-held.texture.get_height()*(0.5 if direction in [0,2] else 0.58 if actor.aim.x >= 0 else 0.42))
		held.scale = Vector2.ONE*actor.weapon_scale()/held.texture.get_width()
		held.position = actor.render_offset+actor.weapon_grip()
		held.rotation = actor.weapon_direction().angle()
		held.flip_v = actor.aim.x < 0
		held.show_behind_parent = false
