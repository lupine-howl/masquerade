class_name PoseToolBar
extends PanelContainer

@onready var mode_bar: PoseModeBar = %PoseModeBar

func _ready() -> void:
	PoseTabStyles.apply_toolbar_panel(self)
	if mode_bar:
		_style_tool_check(mode_bar.posing_check)

func _style_tool_check(check: CheckBox) -> void:
	const TOOL_SIZE := PoseTabStyles.TOOL_BUTTON_SIZE
	check.custom_minimum_size = Vector2(TOOL_SIZE, TOOL_SIZE)
	check.focus_mode = Control.FOCUS_NONE
