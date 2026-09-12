extends Node3D
@export var route:PackedVector3Array=[]
@export var speed:=.9
@export var outfit:="civilian_sage"
var destination:=1
var forward:=true
var elapsed:=0.0
var textures:={}
func _ready():
 for direction in ["front","back","left","right"]:
  for frame in 3:textures[direction+str(frame)]=load("res://assets/models/meadow_expansion/textures/"+outfit+"_"+direction+"_"+str(frame)+".png")
func _process(delta):
 if route.size()<2:return
 var movement=route[destination]-position
 var direction=("right" if movement.x>0 else "left") if absf(movement.x)>absf(movement.z) else ("front" if movement.z>0 else "back")
 elapsed+=delta
 $Sprite.texture=textures[direction+str([0,1,0,2][int(elapsed*5)%4])]
 position=position.move_toward(route[destination],speed*delta)
 if position.distance_to(route[destination])<.02:
  if destination==route.size()-1:forward=false
  elif destination==0:forward=true
  destination+=1 if forward else -1
