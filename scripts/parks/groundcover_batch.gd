@tool
extends MultiMeshInstance3D

@export var placements: Array[Transform3D]=[]

func _ready() -> void:
	if multimesh==null:return
	multimesh.instance_count=placements.size()
	for i in placements.size():multimesh.set_instance_transform(i,placements[i])
