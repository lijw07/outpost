extends Control

const FADE_SECONDS := 0.6

const BACKGROUNDS: Array[String] = [
	"res://assets/loading/loading_forest_camp.png",
	"res://assets/loading/loading_gas_station.png",
	"res://assets/loading/loading_flooded_town.png",
	"res://assets/loading/loading_scrapyard.png",
]

const TIPS: Array[String] = [
	"WALLS BUY TIME - TRAPS BUY MORE",
	"SCAVENGE BY DAY - FORTIFY BY NIGHT",
	"NOISE DRAWS THE HORDE",
	"A LIT CAMP IS A SEEN CAMP",
	"SPLIT UP TO GATHER - REGROUP TO HOLD",
]

@onready var _background: TextureRect = %Background
@onready var _tip: Label = %Tip
@onready var _progress: ProgressBar = %Progress
@onready var _fade: ColorRect = %Fade

var _target := ""
var _first_frame := true

func _ready() -> void:
	_background.texture = load(BACKGROUNDS.pick_random())
	_tip.text = TIPS.pick_random()
	_target = GameSession.pending_scene
	if _target.is_empty():
		_target = GameSession.MENU_SCENE
	create_tween().tween_property(_fade, "color:a", 0.0, FADE_SECONDS)

func _process(_delta: float) -> void:
	# Display the loading screen before loading on the main thread. Godot 4.7.2's
	# threaded loader leaks RefCounted objects for this project's scene resources.
	if _first_frame:
		_first_frame = false
		return
	set_process(false)
	var packed := load(_target) as PackedScene
	if packed == null:
		get_tree().change_scene_to_file(GameSession.MENU_SCENE)
		return
	_progress.value = 100.0
	get_tree().change_scene_to_packed(packed)
