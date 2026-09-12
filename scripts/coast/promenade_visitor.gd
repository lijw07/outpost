extends Node3D
@export var route:PackedVector3Array=[]
@export var speed:=1.1
var destination:=1
var forward:=true
func _ready()->void:add_to_group("town_pedestrians")
func _process(delta:float)->void:
	if route.size()<2:return
	var target:Vector3=route[destination]
	var movement:=target-position
	var sprite:Sprite3D=$Sprite
	sprite.frame=(1 if movement.x>0 else 3) if absf(movement.x)>absf(movement.z) else (0 if movement.z>0 else 2)
	position=position.move_toward(target,delta*speed)
	if position.distance_to(target)<.01:
		if destination==route.size()-1:forward=false
		elif destination==0:forward=true
		destination+=1 if forward else -1
