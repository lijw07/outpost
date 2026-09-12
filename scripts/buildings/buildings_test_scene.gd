extends "res://scripts/world/test_scene.gd"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			for building in world.get_node("Buildings").get_children():
				if building.toggle_nearest_door(player.global_position):
					if overlay_built:
						for child in wireframes.get_children():
							child.free()
						_build_collision_overlay()
					return
			if world.has_node("Assembly/Door"):
				super._unhandled_input(event)
			return
		if event.keycode == KEY_R:
			for building in world.get_node("Buildings").get_children():
				building.interior_preview = not building.interior_preview
			return
	super._unhandled_input(event)
