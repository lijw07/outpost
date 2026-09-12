@tool
extends PanelContainer

const UI = preload("res://scripts/ui/meadow/ui.gd")
const Badge = preload("res://scripts/ui/meadow/badge.gd")
var title: Label
var dish: Label
var badge: PanelContainer
var progress: ProgressBar

func _ready() -> void:
	var column := VBoxContainer.new()
	add_child(column)
	title = UI.label("TABLE", &"Caption")
	column.add_child(title)
	var row := HBoxContainer.new()
	column.add_child(row)
	row.add_child(UI.icon(preload("res://assets/ui/meadow/icons/soup.svg")))
	dish = UI.label("Garden soup")
	row.add_child(dish)
	badge = Badge.new()
	column.add_child(badge)
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.custom_minimum_size.y = 6
	column.add_child(progress)

func configure(data: Dictionary) -> void:
	title.text = str(data.get("title", "TABLE"))
	dish.text = str(data.get("dish", "Garden soup"))
	badge.text = str(data.get("status", "Waiting"))
	badge.tone = str(data.get("tone", "Neutral"))
	progress.visible = data.has("progress")
	progress.value = clampf(float(data.get("progress", 0)), 0, 1) * 100
