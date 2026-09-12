extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func bounds_of(node: Node3D) -> AABB:
	var box := AABB()
	var found := false
	for visual in node.find_children("*","MeshInstance3D",true,false):
		var next: AABB=visual.global_transform*visual.mesh.get_aabb()
		box=box.merge(next) if found else next
		found=true
	return box
func _run() -> void:
	var district: Node3D=load("res://scenes/world/meadow_restaurant_district.tscn").instantiate()
	root.add_child(district)
	var plots: Array=[]
	var errors: Array[String]=[]
	var roads=[Rect2(-48,18,140,8),Rect2(-12,-54,6,74),Rect2(-40,-32,132,4)]
	for node in district.get_children():
		if node.get_meta("district_scenery",false):
			var box:=bounds_of(node)
			var rect:=Rect2(box.position.x,box.position.z,box.size.x,box.size.z)
			plots.append({"title":node.building_title,"rect":rect,"box":str(box),"floors":node.floor_count})
			for road in roads:
				if rect.intersects(road.grow(-.03)):errors.append(node.building_title+" encroaches on a road: "+str(rect))
	plots.append({"title":"Fern & Flour business plot","rect":Rect2(25.6875,-.3125,14.625,14.3125),"box":"Reserved business","floors":1})
	for i in plots.size():
		for j in range(i+1,plots.size()):
			if plots[i].rect.intersects(plots[j].rect):errors.append(plots[i].title+" overlaps "+plots[j].title)
	var report={"passed":errors.is_empty(),"errors":errors,"properties":plots}
	FileAccess.open("res://output/restaurant/validation/placement.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MEADOW_PLACEMENT ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
