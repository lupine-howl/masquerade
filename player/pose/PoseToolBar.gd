class_name PoseToolBar
extends PanelContainer

@onready var mode_bar: PoseModeBar = %PoseModeBar

func _ready() -> void:
	PoseTabStyles.apply_toolbar_panel(self)
	if not mode_bar:
		return
	for btn in [mode_bar.play_btn, mode_bar.pose_btn, mode_bar.build_btn]:
		_style_mode_button(btn)


func _style_mode_button(btn: Button) -> void:
	if btn == null:
		return
	const TOOL_SIZE := PoseTabStyles.TOOL_BUTTON_SIZE
	btn.custom_minimum_size = Vector2(TOOL_SIZE, TOOL_SIZE)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 9)
	btn.clip_text = true
