extends SceneTree

const OUTPUT_PATH := "res://assets/vfx/blood_drip/blood_drips.tres"
const SOURCE_DIR := "res://assets/vfx/blood_drip/"
const ANIMATIONS := {"small": 8, "large": 8, "double": 8}
const FRAME_RATE := 9.0

func _initialize() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for animation: String in ANIMATIONS:
		frames.add_animation(animation)
		frames.set_animation_speed(animation, FRAME_RATE)
		frames.set_animation_loop(animation, true)
		for index in ANIMATIONS[animation]:
			var path := "%sdrip_%s_%02d.png" % [SOURCE_DIR, animation, index]
			frames.add_frame(animation, load(path))
	var err := ResourceSaver.save(frames, OUTPUT_PATH)
	print("sprite frames saved: ", error_string(err))
	quit()
