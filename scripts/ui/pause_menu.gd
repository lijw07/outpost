extends Control

var _busy := false

func _ready() -> void:
	$PauseScreen/ChainRig.adopt($PauseScreen/Content)
	%ResumeButton.pressed.connect(resume)
	%PauseSettingsButton.pressed.connect(_show_settings)
	%ReturnButton.pressed.connect(GameSession.return_to_menu)
	$SettingsPanel.back_requested.connect(_close_settings)

func open() -> void:
	$PauseScreen/ChainRig.get_node("%SubtitleLabel").text = GameSession.world_name if not GameSession.world_name.is_empty() else "THE MEADOW"
	$SettingsPanel.hide()
	$PauseScreen.show()
	show()
	get_tree().paused = true
	%ResumeButton.grab_focus()

func resume() -> void:
	if _busy:
		return
	hide()
	get_tree().paused = false
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()

func _show_settings() -> void:
	if _busy:
		return
	_busy = true
	var rig := $PauseScreen/ChainRig
	rig.hoist()
	await rig.hoisted
	$PauseScreen.hide()
	$SettingsPanel.show()
	$SettingsPanel.focus_first()
	_busy = false

func _close_settings() -> void:
	if _busy:
		return
	_busy = true
	var rig := $SettingsPanel/ChainRig
	rig.hoist()
	await rig.hoisted
	$SettingsPanel.hide()
	$PauseScreen.show()
	%PauseSettingsButton.grab_focus()
	_busy = false

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _busy:
			return
		if $SettingsPanel.visible:
			$SettingsPanel.request_back()
		else:
			resume()
