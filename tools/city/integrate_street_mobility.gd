extends SceneTree

const BASE := "res://assets/models/city/street_mobility/"
const DRIVER := preload("res://scripts/vehicles/drivable_vehicle.gd")
const FIXTURE := preload("res://scripts/vehicles/street_fixture.gd")
var errors: Array[String] = []
var records: Array = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(BASE + "scenes")
	DirAccess.make_dir_recursive_absolute("res://output/street_mobility")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(BASE + "catalog.json"))
	for asset in catalog.assets:
		build_asset(asset)
	var report := {"passed": errors.is_empty(), "errors": errors, "assets": records}
	FileAccess.open("res://output/street_mobility/integration.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("STREET_INTEGRATION ", JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)

func own(node: Node, scene: Node) -> void:
	for child in node.get_children():
		child.owner = scene
		if child.scene_file_path.is_empty():
			own(child, scene)

func collect(node: Node3D, parent_transform: Transform3D, meshes: Array, in_wheel := false, in_fork := false) -> void:
	var transform := parent_transform * node.transform
	in_wheel = in_wheel or String(node.name).begins_with("wheel_")
	in_fork = in_fork or (String(node.name).begins_with("fork") and not node is MeshInstance3D)
	if node is MeshInstance3D:
		var points := PackedVector3Array()
		for point in node.mesh.get_faces():
			points.append(transform * point)
		meshes.append({"node": node, "transform": transform, "points": points, "wheel": in_wheel, "fork": in_fork})
	for child in node.get_children():
		if child is Node3D:
			collect(child, transform, meshes, in_wheel, in_fork)

func build_asset(asset: Dictionary) -> void:
	var packed_model = load(BASE + "gltf/" + asset.id + ".gltf") as PackedScene
	if packed_model == null:
		errors.append(asset.id + ": missing imported model")
		return
	var scene: Node3D
	if asset.category == "vehicle":
		scene = CharacterBody3D.new()
		scene.set_script(DRIVER)
		scene.vehicle_id = asset.id
		scene.wheelbase = asset.wheelbase / 16.0
		scene.wheel_radius = asset.wheel_radius / 16.0
		scene.rear_steering = asset.id == "forklift"
		scene.maximum_speed = {"sedan": 9.0, "van": 7.5, "ambulance": 9.5, "bus": 6.0, "forklift": 3.5}[asset.id]
		scene.reverse_speed = 2.5 if asset.id == "forklift" else 4.0
	else:
		scene = Node3D.new()
		scene.set_script(FIXTURE)
		scene.fixture_id = asset.id
	scene.name = String(asset.id).to_pascal_case()
	scene.set_meta("asset_id", asset.id)
	scene.set_meta("source", BASE + "blockbench/" + asset.id + ".bbmodel")
	var model := packed_model.instantiate() as Node3D
	model.name = "Model"
	scene.add_child(model)
	var meshes: Array = []
	collect(model, Transform3D.IDENTITY, meshes)
	if asset.category == "vehicle":
		var body_points := PackedVector3Array()
		for mesh in meshes:
			if mesh.wheel:
				if String(mesh.node.name).begins_with("tire"):
					convex(scene, mesh.points, "TireCollision")
			elif mesh.fork:
				var shape := convex(scene, mesh.points, "ForkCollision")
				shape.set_meta("fork_origin", shape.position)
			else:
				body_points.append_array(mesh.points)
		convex(scene, body_points, "BodyCollision")
	else:
		var body := StaticBody3D.new()
		body.name = "Body"
		scene.add_child(body)
		var faces := PackedVector3Array()
		for mesh in meshes:
			if asset.id == "wheelie_bin" and String(mesh.node.name).begins_with("lid"):
				continue
			faces.append_array(mesh.points)
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		var collision := CollisionShape3D.new()
		collision.name = "MeshCollision"
		collision.shape = shape
		body.add_child(collision)
		if asset.id == "wheelie_bin":
			scene.set_editable_instance(model, true)
			var hinge := model.find_child("lid_hinge", true, false)
			var lid_body := AnimatableBody3D.new()
			lid_body.name = "LidCollision"
			lid_body.sync_to_physics = false
			hinge.add_child(lid_body)
			lid_body.owner = scene
			for mesh in meshes:
				if String(mesh.node.name).begins_with("lid"):
					var c := CollisionShape3D.new()
					c.shape = mesh.node.mesh.create_convex_shape()
					c.transform = mesh.node.transform
					lid_body.add_child(c)
					c.owner = scene
	if String(asset.id).begins_with("street_light"):
		for mesh in meshes:
			if String(mesh.node.name).begins_with("warm_glass"):
				var light := OmniLight3D.new()
				light.name = "LanternLight"
				light.position = mesh.transform * mesh.node.mesh.get_aabb().get_center()
				light.light_color = Color("ffe1a0")
				light.light_energy = 1.4
				light.omni_range = 5.0
				scene.add_child(light)
	own(scene, scene)
	var packed := PackedScene.new()
	packed.pack(scene)
	var path: String = BASE + "scenes/" + asset.id + ".tscn"
	var error := ResourceSaver.save(packed, path)
	if error != OK:
		errors.append(asset.id + ": scene save failed")
	records.append({"id": asset.id, "scene": path, "meshes": meshes.size()})
	scene.free()

func convex(parent: Node3D, points: PackedVector3Array, label: String) -> CollisionShape3D:
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.name = label
	collision.shape = shape
	parent.add_child(collision)
	return collision
