class_name PoseAssistantPanel
extends VBoxContainer

signal grounded_toggled(enabled: bool)
signal duration_changed(duration: float)
signal speed_changed(speed: float)
signal animation_created(anim_name: String)

const RESET_ANIM_NAME := "RESET"

@export var hang_control_marker: PoseMarker

@onready var grounded_check: CheckBox = %GroundedCheck
@onready var btn_reset: Button = %BtnReset
@onready var btn_hang: Button = %BtnHang
@onready var btn_clear: Button = %BtnClear
@onready var btn_key_all: Button = %BtnKeyAll
@onready var btn_swap_all_siblings: Button = %BtnSwapAllSiblings
@onready var new_anim_edit: LineEdit = %NewAnimEdit
@onready var btn_create: Button = %BtnCreate
@onready var steps_spin: SpinBox = %StepsSpin
@onready var speed_spin: SpinBox = %SpeedSpin

var _pose_controller: PoseController
var _timeline: TimelineManager
var _anim_browser: PoseAnimBrowser
var _get_current_animation: Callable
var _on_refresh_visuals: Callable
var _on_markers_changed: Callable
var _on_key_all: Callable
var _on_swap_all_siblings: Callable
var _syncing_timing: bool = false

func setup(
	pose_controller: PoseController,
	p_timeline: TimelineManager,
	anim_browser: PoseAnimBrowser,
	get_current_animation: Callable,
	on_refresh_visuals: Callable,
	on_markers_changed: Callable = Callable(),
	on_key_all: Callable = Callable(),
	on_swap_all_siblings: Callable = Callable()
) -> void:
	_pose_controller = pose_controller
	_timeline = p_timeline
	_anim_browser = anim_browser
	_get_current_animation = get_current_animation
	_on_refresh_visuals = on_refresh_visuals
	_on_markers_changed = on_markers_changed
	_on_key_all = on_key_all
	_on_swap_all_siblings = on_swap_all_siblings
	if not hang_control_marker and pose_controller:
		hang_control_marker = _find_marker_by_name("Crown")
	sync_timing_ui()

func _ready() -> void:
	grounded_check.toggled.connect(_on_grounded_toggled)
	btn_reset.pressed.connect(_on_reset_pressed)
	btn_hang.pressed.connect(_on_hang_pressed)
	btn_clear.pressed.connect(_on_clear_pressed)
	btn_key_all.pressed.connect(_on_key_all_pressed)
	btn_swap_all_siblings.pressed.connect(_on_swap_all_siblings_pressed)
	btn_create.pressed.connect(_on_create_pressed)
	steps_spin.value_changed.connect(_on_steps_changed)
	speed_spin.value_changed.connect(_on_speed_changed)

func is_grounded() -> bool:
	return grounded_check.button_pressed

func sync_timing_ui() -> void:
	if not _timeline or _get_current_animation.is_null():
		return
	var anim_name: String = _get_current_animation.call()
	if anim_name == "" or not _timeline.anim_player or not _timeline.anim_player.has_animation(anim_name):
		return
	var anim := _timeline.anim_player.get_animation(anim_name)
	_syncing_timing = true
	steps_spin.set_value_no_signal(_time_to_steps(anim.length))
	speed_spin.set_value_no_signal(_timeline.get_speed_scale(anim_name))
	_syncing_timing = false

func _time_to_steps(duration_seconds: float) -> int:
	if not _timeline or _timeline.step_duration <= 0.0:
		return 0
	return int(round(duration_seconds / _timeline.step_duration))

func _steps_to_time(steps: int) -> float:
	return steps * _timeline.step_duration if _timeline else 0.0

func _find_marker_by_name(marker_name: String) -> PoseMarker:
	if not _pose_controller:
		return null
	for m in _pose_controller.all_markers:
		if m.name == marker_name:
			return m
	return null

func _on_grounded_toggled(enabled: bool) -> void:
	if _pose_controller:
		_pose_controller.set_pose_grounded(enabled)
	grounded_toggled.emit(enabled)

func _on_reset_pressed() -> void:
	if _anim_browser:
		_anim_browser.play_preview_animation(RESET_ANIM_NAME)

func _on_hang_pressed() -> void:
	if not _pose_controller:
		return
	var hang_marker := hang_control_marker if hang_control_marker else _find_marker_by_name("Crown")
	if not hang_marker:
		push_warning("PoseAssistantPanel: no hang control marker configured")
		return
	_pose_controller.set_hang_mode(hang_marker)
	if not _on_markers_changed.is_null():
		_on_markers_changed.call()

func _on_clear_pressed() -> void:
	if _get_current_animation.is_null() or not _timeline:
		return
	var anim_name: String = _get_current_animation.call()
	if anim_name == "":
		return
	_timeline.clear_animation(anim_name)
	if not _on_refresh_visuals.is_null():
		_on_refresh_visuals.call()

func _on_key_all_pressed() -> void:
	if not _on_key_all.is_null():
		_on_key_all.call()

func _on_swap_all_siblings_pressed() -> void:
	if not _on_swap_all_siblings.is_null():
		_on_swap_all_siblings.call()

func _on_create_pressed() -> void:
	if not _timeline:
		return
	var anim_name := new_anim_edit.text.strip_edges()
	if anim_name == "":
		anim_name = _suggest_new_animation_name()
		new_anim_edit.text = anim_name
	if _timeline.anim_player and _timeline.anim_player.has_animation(anim_name):
		push_warning("PoseAssistantPanel: animation already exists: %s" % anim_name)
		return
	var steps := int(steps_spin.value)
	var length := _steps_to_time(steps)
	if not _timeline.create_animation(anim_name, length):
		return
	if _anim_browser:
		_anim_browser.refresh_animation_list(anim_name)
	sync_timing_ui()
	animation_created.emit(anim_name)

func _suggest_new_animation_name() -> String:
	if not _timeline or not _timeline.anim_player:
		return "pose_1"
	var index := 1
	while _timeline.anim_player.has_animation("pose_%d" % index):
		index += 1
	return "pose_%d" % index

func _on_steps_changed(steps: float) -> void:
	if _syncing_timing or not _timeline or _get_current_animation.is_null():
		return
	var anim_name: String = _get_current_animation.call()
	if anim_name == "":
		return
	var next_time := _steps_to_time(int(steps))
	_timeline.set_length(anim_name, next_time)
	if _anim_browser:
		_anim_browser.sync_timing_ui_for_current_animation()
	duration_changed.emit(next_time)
	if not _on_refresh_visuals.is_null():
		_on_refresh_visuals.call()

func _on_speed_changed(speed: float) -> void:
	if _syncing_timing or not _timeline or _get_current_animation.is_null():
		return
	var anim_name: String = _get_current_animation.call()
	if anim_name == "":
		return
	_timeline.key_speed_scale(anim_name, speed)
	if _timeline.anim_player:
		_timeline.anim_player.speed_scale = speed
	if _anim_browser:
		_anim_browser.sync_timing_ui_for_current_animation()
	speed_changed.emit(speed)
