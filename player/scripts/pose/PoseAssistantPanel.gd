class_name PoseAssistantPanel
extends HBoxContainer

signal grounded_toggled(enabled: bool)

@onready var grounded_check: CheckBox = %GroundedCheck

var _pose_controller: PoseController

func setup(pose_controller: PoseController) -> void:
	_pose_controller = pose_controller
	grounded_check.toggled.connect(_on_grounded_toggled)

func is_grounded() -> bool:
	return grounded_check.button_pressed

func _on_grounded_toggled(enabled: bool) -> void:
	if _pose_controller:
		_pose_controller.set_pose_grounded(enabled)
	grounded_toggled.emit(enabled)
