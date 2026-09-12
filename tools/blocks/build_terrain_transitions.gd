extends SceneTree

const OUTPUT := "res://assets/models/blocks/transitions/"
const PAIRS := [["road_asphalt","sidewalk"],["dirt","grass"],["sand","grass"],["gravel","grass"],["road_asphalt","grass"],["sidewalk","grass"],["road_asphalt","dirt"],["road_asphalt","gravel"],["dirt","sand"]]
const SHAPES := {"edge":[0],"outer_corner":[0,3],"inner_corner":[7],"strip":[1,3],"end":[0,1,3],"island":[0,1,2,3]}
var transitions := preload("res://scripts/world/terrain_transitions.gd").new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for folder in ["scenes","textures","blockbench","gltf","collision"]:
		DirAccess.make_dir_recursive_absolute(OUTPUT+folder)
	DirAccess.make_dir_recursive_absolute("res://output/terrain_transitions/review")
	var catalog: Array = []
	var native: Array = []
	for pair in PAIRS:
		for shape in SHAPES:
			var neighbors := ["","","","","","","",""]
			for direction in SHAPES[shape]:
				neighbors[direction] = pair[1]
			var data: Dictionary = transitions.variant(pair[0],neighbors)
			var id: String = pair[0] + "_to_" + pair[1] + "_" + shape
			data.image.save_png(OUTPUT+"textures/"+id+".png")
			var scene := Node3D.new()
			scene.name = id.to_pascal_case()
			scene.set_meta("asset_id",id)
			scene.set_meta("terrain_block",true)
			scene.set_meta("tile_size",2.0)
			scene.set_meta("placement_anchor","base")
			scene.set_meta("transition_base",pair[0])
			scene.set_meta("transition_neighbor",pair[1])
			scene.set_meta("transition_shape",shape)
			var body := StaticBody3D.new()
			body.name = "Body"
			scene.add_child(body)
			body.owner = scene
			var visual := MeshInstance3D.new()
			visual.name = "Model"
			visual.mesh = data.mesh
			body.add_child(visual)
			visual.owner = scene
			var collision := CollisionShape3D.new()
			collision.name = "MeshCollision"
			collision.shape = visual.mesh.create_trimesh_shape()
			body.add_child(collision)
			collision.owner = scene
			ResourceSaver.save(collision.shape,OUTPUT+"collision/"+id+".res")
			var packed := PackedScene.new()
			packed.pack(scene)
			ResourceSaver.save(packed,OUTPUT+"scenes/"+id+".tscn")
			var meshes: Array = []
			for surface in visual.mesh.get_surface_count():
				var arrays := visual.mesh.surface_get_arrays(surface)
				var vertices: Array = []
				var uv: Array = []
				for point in arrays[Mesh.ARRAY_VERTEX]:
					vertices.append([point.x*16,point.y*16,point.z*16])
				for point in arrays[Mesh.ARRAY_TEX_UV]:
					uv.append([point.x*32,point.y*32])
				meshes.append({"vertices":vertices,"uv":uv,"texture":id if surface == 0 else transitions.TEXTURES[pair[0]]})
			native.append({"id":id,"meshes":meshes})
			catalog.append({"id":id,"base":pair[0],"neighbor":pair[1],"shape":shape,"neighbors":neighbors,"scene":OUTPUT+"scenes/"+id+".tscn","model":OUTPUT+"gltf/"+id+".gltf","native":OUTPUT+"blockbench/"+id+".bbmodel","top_y":2.0625 if pair[1] == "sidewalk" else 2.0})
			scene.free()
	FileAccess.open(OUTPUT+"catalog.json",FileAccess.WRITE).store_string(JSON.stringify({"assets":catalog,"tile_pixels":32,"tile_units":2,"origin":"base Y=0","orientation":"edge faces -Z; outer corner -Z/-X; inner corner -X/-Z diagonal; rotate in 90 degree steps"},"\t"))
	FileAccess.open("res://output/terrain_transitions/native_geometry.json",FileAccess.WRITE).store_string(JSON.stringify(native))
	print("TRANSITION_ASSETS ",catalog.size())
	quit()
