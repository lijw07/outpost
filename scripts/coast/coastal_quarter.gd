@tool
extends Node3D
func _ready()->void:
	var office:=get_node_or_null("HarborCottage")
	if office==null:return
	for label in office.find_children("*","Label3D",true,false):
		label.text="HARBOR OFFICE"
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
