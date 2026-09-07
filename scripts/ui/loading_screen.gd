extends Control

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

var _target := ""

func _ready() -> void:
	_background.texture = load(BACKGROUNDS.pick_random())
	_tip.text = TIPS.pick_random()
	_target = GameSession.pending_scene
	if _target.is_empty():
		_target = GameSession.MENU_SCENE
	ResourceLoader.load_threaded_request(_target)

func _process(_delta: float) -> void:
	var parts: Array = []
	var status := ResourceLoader.load_threaded_get_status(_target, parts)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_progress.value = float(parts[0]) * 100.0
		ResourceLoader.THREAD_LOAD_LOADED:
			set_process(false)
			_progress.value = 100.0
			var packed := ResourceLoader.load_threaded_get(_target) as PackedScene
			get_tree().change_scene_to_packed(packed)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			set_process(false)
			get_tree().change_scene_to_file(GameSession.MENU_SCENE)
