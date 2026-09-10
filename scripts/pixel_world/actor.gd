extends CharacterBody3D
## A small 2D pixel puppet in a 3D collision world, viewed by a fixed camera.
const Composer := preload("res://scripts/characters/compositor.gd")
const Appearance := preload("res://scripts/characters/appearance.gd")
const MELEE := {"bat":0,"spiked_bat":1,"knife":2,"machete":3,"axe":4,"crowbar":5,"shovel":6,"spear":7}
const EXTRA_MELEE := {"golf_club":0,"pipe":1,"katana":2,"sledgehammer":3,"wrench":4,"pickaxe":5,"hockey_stick":6,"fire_poker":7}
const EXTRA_GUNS := {"scar":8,"m4":9,"ak":10,"dmr":11,"machine_gun":12,"shotgun":13,"smg":14,"grenade_launcher":15}
const Art := preload("res://scripts/pixel_world/art.gd")
var source_actor: Node2D
var card: Node3D
var body: Sprite3D
var weapon: Sprite3D
var arms: Array[Sprite3D] = []
var palette: ShaderMaterial
var controlled := false
var outfit := 0
var _facing := -1
var appearance: Dictionary = {}
var equipment: Dictionary = {}
var _modular_stride := -1

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.23
	shape.height = 0.7
	collider.shape = shape
	collider.position.y = 0.35
	add_child(collider)
	card = Node3D.new()
	card.rotation.x = -PI/4
	add_child(card)
	body = Art.sprite(Art.frame("characters",0))
	palette = ShaderMaterial.new()
	palette.shader = preload("res://assets/pixel_world/actor.gdshader")
	body.material_override = palette
	card.add_child(body)
	weapon = Art.sprite(Art.frame("weapons",0))
	card.add_child(weapon)
	for side in 2:
		var image := Image.create(3,7,false,Image.FORMAT_RGBA8)
		image.fill(Color("172b29"))
		var sleeve: Color = [Color("3c6883"),Color("626d43"),Color("354956"),Color("8b4a36"),Color("66713e"),Color("42596b"),Color("41464a")][clampi(outfit,0,6)]
		image.fill_rect(Rect2i(1,1,1,4),Color("657152") if source_actor.team else sleeve)
		image.fill_rect(Rect2i(1,5,1,2),Color("e3b58c"))
		var arm := Art.sprite(ImageTexture.create_from_image(image))
		card.add_child(arm)
		arms.append(arm)
	sync_pose()

func sync_pose() -> void:
	if source_actor == null:
		return
	card.position = Vector3(roundf(position.x/Art.PIXEL)*Art.PIXEL-position.x,0,roundf(position.z/(Art.PIXEL*sqrt(2)))*Art.PIXEL*sqrt(2)-position.z)
	var actor := source_actor
	var facing: int = actor.facing
	var sheet := "clothing" if outfit >= 3 and not actor.team else "characters"
	var character: int = 3 if actor.team else posmod(outfit-3,4) if outfit >= 3 else outfit
	var stride: int = int(actor.phase*4)%4 if actor.velocity.length_squared()>1 else 0
	if _facing != facing or (not appearance.is_empty() and _modular_stride != stride):
		_modular_stride = stride
		_facing = facing
		var texture := Art.frame(sheet,character*4+facing) if appearance.is_empty() else Composer.texture(appearance,facing,stride,equipment)
		body.pixel_size = Art.PIXEL if appearance.is_empty() else Art.PIXEL/Composer.DETAIL
		body.texture = texture
		palette.set_shader_parameter("sprite_texture",texture)
		palette.set_shader_parameter("pixel_size",Vector2(1.0/texture.get_width(),1.0/texture.get_height()))
	var moving: bool = actor.velocity.length_squared()>1
	var step: float = actor.phase*TAU
	var bob: float = round(absf(sin(step)))*Art.PIXEL if moving else 0.0
	body.position = Vector3(0,(12 if appearance.is_empty() else 14)*Art.PIXEL+bob,0)
	palette.set_shader_parameter("moving",moving and appearance.is_empty())
	palette.set_shader_parameter("modular_body",not appearance.is_empty())
	palette.set_shader_parameter("stride",step)
	palette.set_shader_parameter("facing",facing)
	palette.set_shader_parameter("tint",Vector3(1,0.65,0.55) if actor.hurt>0 else Vector3.ONE)
	var armed: bool = actor.team == 0 and actor.carrying == 0 and actor.action not in ["build","gather"]
	weapon.visible = actor.health > 0 and (armed or actor.carrying>0 or actor.action == "build")
	palette.set_shader_parameter("replace_arms",weapon.visible or actor.action == "attack")
	var melee: bool = actor.loadout_slot == 0 or actor.action == "melee"
	var right := 1.0 if facing in [0,1] else -1.0
	var grip := Vector2(right*5,-11)
	var angle := -PI/2
	weapon.flip_h = false
	if armed:
		_set_weapon_texture(actor,melee,facing)
		if not melee:
			angle = actor.aim.angle()-[PI/2,0,-PI/2,PI][facing]
			grip = Vector2(actor.aim.x*4,-11+actor.aim.y*2)
		elif actor.action == "melee":
			angle = actor.weapon_direction().angle()
			var progress: float = actor.melee_progress()
			grip.y -= 4*sin(progress*PI*2)
		weapon.flip_v = melee and facing in [2,3]
	elif actor.carrying > 0:
		weapon.texture = Art.frame("props",15)
		angle = 0
		grip = Vector2(0,-8)
	else:
		weapon.texture = Art.frame("weapons",4)
		angle = -PI/2+sin(actor.action_phase)*0.8
	weapon.offset = Vector2(weapon.texture.get_width()*0.35,0) if melee else Vector2.ZERO
	weapon.position = Vector3(grip.x*Art.PIXEL,-grip.y*Art.PIXEL+bob,0.02 if facing != 2 else -0.02)
	weapon.rotation.z = -angle
	for index in 2:
		var arm := arms[index]
		arm.visible = actor.health > 0 and (weapon.visible or actor.action == "attack")
		var side := -1.0 if index == 0 else 1.0
		var hand := Vector2(side*5,-8+sin(step+index*PI)*2) if moving else Vector2(side*5,-8)
		if actor.action == "attack":
			hand += actor.aim*float(actor.zombie_reach())*5
		elif actor.carrying > 0:
			hand = grip+Vector2(side*4,0)
		elif (armed or actor.action == "build") and (side == right or not melee):
			hand = grip+actor.aim*3 if not melee and side != right else grip
		var shoulder := Vector2(side*4,-13)
		var mid := shoulder.lerp(hand,0.5)
		arm.position = Vector3(mid.x*Art.PIXEL,-mid.y*Art.PIXEL+bob,0.025 if facing != 2 else -0.025)
		arm.rotation.z = -(hand-shoulder).angle()+PI/2
		arm.modulate = Color.WHITE
	if actor.health <= 0:
		card.rotation.z = lerpf(0,PI/2,clampf(actor.death_age/0.35,0,1))
		card.scale = Vector3.ONE*(1-smoothstep(2.5,4,actor.death_age))
		body.position.y = 6*Art.PIXEL
	else:
		card.rotation.z = 0
		card.scale = Vector3.ONE

func _set_weapon_texture(actor: Node2D, melee: bool, facing: int) -> void:
	if melee:
		var melee_id: String = actor.melee_weapon.id
		weapon.texture = Art.frame("variations",EXTRA_MELEE[melee_id]) if EXTRA_MELEE.has(melee_id) else Art.frame("weapons",MELEE.get(melee_id,0))
		return
	var id: String = actor.firearm.id
	if facing in [1,3] and EXTRA_GUNS.has(id):
		weapon.texture = Art.frame("variations",EXTRA_GUNS[id])
		weapon.flip_h = facing == 3
		return
	var family := 0 if id == "pistol" else 2 if id in ["sniper","dmr"] else 3 if id in ["rocket_launcher","grenade_launcher"] else 1
	weapon.texture = Art.frame("gunviews",family*4+[1,0,2,3][facing])

func set_appearance(profile: Dictionary, worn: Dictionary = {}) -> void:
	appearance = Appearance.sanitize(profile)
	equipment = Appearance.equipment(worn)
	_facing = -1
	for arm in arms:
		var pixels := Image.create(3,7,false,Image.FORMAT_RGBA8)
		pixels.fill(Color("222b2a"))
		pixels.fill_rect(Rect2i(1,1,1,4),Appearance.color(appearance.top_color))
		pixels.fill_rect(Rect2i(1,5,1,2),Appearance.color(appearance.skin,true))
		arm.texture = ImageTexture.create_from_image(pixels)
	sync_pose()
