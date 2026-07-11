class_name PoseModeBar
extends VBoxContainer

enum Mode { PLAY, POSE, BUILD }

signal mode_changed(mode: Mode)
signal posing_toggled(is_posing: bool)

@onready var play_btn: Button = %PlayBtn
@onready var pose_btn: Button = %PoseBtn
@onready var build_btn: Button = %BuildBtn

var _mode: Mode = Mode.PLAY
var _button_group: ButtonGroup


func _ready() -> void:
	_button_group = ButtonGroup.new()
	_button_group.allow_unpress = false
	for btn in [play_btn, pose_btn, build_btn]:
		if btn:
			btn.button_group = _button_group
			btn.toggle_mode = true
	if play_btn:
		play_btn.pressed.connect(func(): _set_mode(Mode.PLAY))
	if pose_btn:
		pose_btn.pressed.connect(func(): _set_mode(Mode.POSE))
	if build_btn:
		build_btn.pressed.connect(func(): _set_mode(Mode.BUILD))
	_set_mode(Mode.PLAY, false)


func get_mode() -> Mode:
	return _mode


func is_posing() -> bool:
	return _mode == Mode.POSE


func _set_mode(mode: Mode, emit_signal: bool = true) -> void:
	_mode = mode
	if play_btn:
		play_btn.button_pressed = mode == Mode.PLAY
	if pose_btn:
		pose_btn.button_pressed = mode == Mode.POSE
	if build_btn:
		build_btn.button_pressed = mode == Mode.BUILD
	if emit_signal:
		mode_changed.emit(mode)
		posing_toggled.emit(mode == Mode.POSE)
