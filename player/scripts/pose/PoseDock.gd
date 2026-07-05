class_name PoseDock
extends PanelContainer

func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	add_theme_stylebox_override("panel", style)
