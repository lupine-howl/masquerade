class_name PoseToolBar
extends PanelContainer

signal key_all_pressed

const TOOL_SIZE := PoseTabStyles.TOOL_BUTTON_SIZE

@onready var mode_bar: PoseModeBar = %PoseModeBar
@onready var btn_key_all: Button = %BtnKeyAll

func _ready() -> void:
	PoseTabStyles.apply_toolbar_panel(self)
	btn_key_all.pressed.connect(func(): key_all_pressed.emit())
	_style_tool_button(btn_key_all)
	if mode_bar:
		_style_tool_check(mode_bar.posing_check)

func _style_tool_button(btn: Button) -> void:
	btn.custom_minimum_size = Vector2(TOOL_SIZE, TOOL_SIZE)
	btn.focus_mode = Control.FOCUS_NONE
	btn.flat = true
	btn.add_theme_font_size_override("font_size", 14)

func _style_tool_check(check: CheckBox) -> void:
	check.custom_minimum_size = Vector2(TOOL_SIZE, TOOL_SIZE)
	check.focus_mode = Control.FOCUS_NONE
