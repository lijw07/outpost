extends SceneTree

const BASE = "/Users/jaili/projects/godot/outpost/assets/models/city/street_mobility/"
var failures: Array[String] = []
var records: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func run() -> void:
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(BASE + "catalog.json"))
	for asset in catalog.assets:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error := document.append_from_file(BASE + "gltf/" + asset.id + ".gltf", state)
		check(error == OK, asset.id + ": glTF load")
		if error != OK:
			continue
		var model := document.generate_scene(state)
		check(model != null, asset.id + ": scene generation")
		if model == null:
			continue
		root.add_child(model)
		var players = model.find_children("*", "AnimationPlayer", true, false)
		var imported_clips: Array = []
		if not asset.animations.is_empty():
			check(players.size() == 1, asset.id + ": animation player")
			if players.size() == 1:
				var player: AnimationPlayer = players[0]
				for animation in asset.animations:
					check(player.has_animation(animation), asset.id + ": missing " + animation)
					if player.has_animation(animation):
						player.play(animation)
						player.seek(player.get_animation(animation).length * 0.4, true)
						player.advance(0)
						imported_clips.append(animation)
				if asset.category == "vehicle":
					var wheels = model.find_children("wheel_*", "Node3D", true, false)
					check(wheels.size() == 4, asset.id + ": four wheel pivots")
					var wheel = model.find_child("wheel_front_left", true, false)
					player.play("drive_forward")
					player.seek(0.125, true)
					player.advance(0)
					var forward: Basis = wheel.basis
					player.play("reverse")
					player.seek(0.125, true)
					player.advance(0)
					check(not forward.is_equal_approx(wheel.basis), asset.id + ": opposing wheel spin")
					var vehicle = model.find_child("vehicle_root", true, false)
					player.play("preview_forward")
					player.seek(0.9, true)
					player.advance(0)
					var forward_z: float = vehicle.position.z
					player.play("preview_reverse")
					player.seek(0.9, true)
					player.advance(0)
					check(forward_z < -0.1 and vehicle.position.z > 0.1, asset.id + ": forward/reverse root displacement")
					var steer = model.find_child("steer_rear_left" if asset.id == "forklift" else "steer_front_left", true, false)
					player.play("steer_left")
					player.seek(0.25, true)
					player.advance(0)
					var left: Basis = steer.basis
					player.play("steer_right")
					player.seek(0.25, true)
					player.advance(0)
					check(not left.is_equal_approx(steer.basis), asset.id + ": opposing steering poses")
		if asset.category == "terrain":
			var meshes = model.find_children("*", "ImporterMeshInstance3D", true, false)
			check(meshes.size() == 1, asset.id + ": single solid block")
			if meshes.size() == 1:
				var size: Vector3 = meshes[0].mesh.get_mesh().get_aabb().size
				check(size.is_equal_approx(Vector3(2, 2, 2)), asset.id + ": imported dimensions " + str(size))
		records.append({"id": asset.id, "imported": true, "clips_sampled": imported_clips.size()})
		model.free()
	var report := {"passed": failures.is_empty(), "assets": records, "failures": failures}
	FileAccess.open(BASE + "review/godot_import_validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
