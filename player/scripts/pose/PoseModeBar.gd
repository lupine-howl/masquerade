class_name PoseModeBar
extends VBoxContainer

signal posing_toggled(is_posing: bool)

@onready var posing_check: CheckBox = %PosingCheck

func _ready() -> void:
	posing_check.button_pressed = true
	posing_check.toggled.connect(_on_posing_toggled)

func is_posing() -> bool:
	return posing_check.button_pressed

func _on_posing_toggled(posing_enabled: bool) -> void:
	posing_toggled.emit(posing_enabled)
