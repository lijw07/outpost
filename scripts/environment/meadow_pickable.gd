extends Sprite2D
## Stationary harvestable patches, such as mushrooms.
signal harvested(kind: String, amount: int)
@export var picked_texture: Texture2D
@export var pickup_kind := "mushrooms"
var picked := false
func _ready() -> void:
	add_to_group("meadow_pickables")
func harvest() -> bool:
	if picked or picked_texture == null: return false
	picked = true
	texture = picked_texture
	harvested.emit(pickup_kind,1)
	return true
