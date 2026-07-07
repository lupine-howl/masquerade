class_name PoseAssistantPanel
extends VBoxContainer

signal grounded_toggled(enabled: bool)
signal animation_created(anim_name: String)
signal player_drive_toggled(enabled: bool)

const RESET_ANIM_NAME := "RESET"

@export var hang_control_marker: PoseMarker

@onready var anim_title: Label = %AnimTitle
@onready var btn_export: Button = %BtnExportAnimation
@onready var loop_check: CheckBox = %LoopCheck
@onready var ctrl_all_check: CheckBox = %CtrlAllCheck
@onready var ctrl_arms_check: CheckBox = %CtrlArmsCheck
@onready var ctrl_legs_check: CheckBox = %CtrlLegsCheck
@onready var ctrl_head_check: CheckBox = %CtrlHeadCheck
@onready var ctrl_root_check: CheckBox = %CtrlRootCheck
@onready var ctrl_player_check: CheckBox = %CtrlPlayerCheck
@onready var grounded_check: CheckBox = %GroundedCheck
@onready var btn_reset: Button = %BtnReset
@onready var btn_norm_horiz: Button = %BtnNormHoriz
@onready var btn_hang: Button = %BtnHang
@onready var btn_fall: Button = %BtnFall
@onready var btn_clear: Button = %BtnClear
@onready var btn_swap_all_siblings: Button = %BtnSwapAllSiblings
@onready var new_anim_edit: LineEdit = %NewAnimEdit
@onready var btn_create: Button = %BtnCreate

var _pose_controller: PoseController
var _timeline: TimelineManager
var _anim_browser: PoseAnimBrowser
var _get_current_animation: Callable
var _on_refresh_visuals: Callable
var _on_markers_changed: Callable
var _on_swap_all_siblings: Callable
var _on_norm_horiz: Callable
var _syncing_timing: bool = false
var _syncing_ragdoll: bool = false
var _ctrl_checks: Dictionary = {}
var _grounded_checks: Array[CheckBox] = []
var _loop_checks: Array[CheckBox] = []
var _player_drive_checks: Array[CheckBox] = []
var _export_buttons: Array[Button] = []

func setup(
	pose_controller: PoseController,
	p_timeline: TimelineManager,
	anim_browser: PoseAnimBrowser,
	get_current_animation: Callable,
	on_refresh_visuals: Callable,
	on_markers_changed: Callable = Callable(),
	on_swap_all_siblings: Callable = Callable(),
	on_norm_horiz: Callable = Callable()
) -> void:
	_pose_controller = pose_controller
	_timeline = p_timeline
	_anim_browser = anim_browser
	_get_current_animation = get_current_animation
	_on_refresh_visuals = on_refresh_visuals
	_on_markers_changed = on_markers_changed
	_on_swap_all_siblings = on_swap_all_siblings
	_on_norm_horiz = on_norm_horiz
	if not hang_control_marker and pose_controller:
		hang_control_marker = _find_marker_by_name("Crown")
	sync_title_ui()
	sync_ragdoll_toggles()

func _ready() -> void:
	_register_ctrl_check("all", ctrl_all_check)
	_register_ctrl_check("arms", ctrl_arms_check)
	_register_ctrl_check("legs", ctrl_legs_check)
	_register_ctrl_check("head", ctrl_head_check)
	_register_ctrl_check("root", ctrl_root_check)
	_register_player_drive_check(ctrl_player_check)
	_register_grounded_check(grounded_check)
	_register_export_button(btn_export)
	_register_loop_check(loop_check)
	btn_reset.pressed.connect(_on_reset_pressed)
	btn_norm_horiz.pressed.connect(_on_norm_horiz_pressed)
	btn_hang.pressed.connect(_on_hang_pressed)
	btn_fall.pressed.connect(_on_fall_pressed)
	btn_clear.pressed.connect(_on_clear_pressed)
	btn_swap_all_siblings.pressed.connect(_on_swap_all_siblings_pressed)
	btn_create.pressed.connect(_on_create_pressed)

func register_timeline_mirrors(
	ctrl_all: CheckBox,
	ctrl_arms: CheckBox,
	ctrl_legs: CheckBox,
	ctrl_head: CheckBox,
	ctrl_root: CheckBox,
	ctrl_player: CheckBox,
	grounded: CheckBox,
	btn_export_mirror: Button,
	loop_check_mirror: CheckBox,
	btn_pose_reset: Button,
	btn_norm: Button,
	btn_hang_action: Button,
	btn_fall_action: Button,
	btn_clear_action: Button,
	btn_swap_all: Button
) -> void:
	_register_ctrl_check("all", ctrl_all)
	_register_ctrl_check("arms", ctrl_arms)
	_register_ctrl_check("legs", ctrl_legs)
	_register_ctrl_check("head", ctrl_head)
	_register_ctrl_check("root", ctrl_root)
	_register_player_drive_check(ctrl_player)
	_register_grounded_check(grounded)
	_register_export_button(btn_export_mirror)
	_register_loop_check(loop_check_mirror)
	btn_pose_reset.pressed.connect(_on_reset_pressed)
	btn_norm.pressed.connect(_on_norm_horiz_pressed)
	btn_hang_action.pressed.connect(_on_hang_pressed)
	btn_fall_action.pressed.connect(_on_fall_pressed)
	btn_clear_action.pressed.connect(_on_clear_pressed)
	btn_swap_all.pressed.connect(_on_swap_all_siblings_pressed)

func _register_ctrl_check(group: String, check: CheckBox) -> void:
	if not _ctrl_checks.has(group):
		_ctrl_checks[group] = []
	if check in _ctrl_checks[group]:
		return
	_ctrl_checks[group].append(check)
	check.toggled.connect(func(enabled: bool) -> void: _on_ctrl_group_toggled(group, enabled))

func _register_grounded_check(check: CheckBox) -> void:
	if check in _grounded_checks:
		return
	_grounded_checks.append(check)
	check.toggled.connect(_on_grounded_toggled)

func _register_export_button(btn: Button) -> void:
	if btn in _export_buttons:
		return
	_export_buttons.append(btn)
	btn.pressed.connect(_on_export_pressed)

func _register_loop_check(check: CheckBox) -> void:
	if check in _loop_checks:
		return
	_loop_checks.append(check)
	check.toggled.connect(_on_loop_toggled)

func _register_player_drive_check(check: CheckBox) -> void:
	if check in _player_drive_checks:
		return
	_player_drive_checks.append(check)
	check.toggled.connect(_on_player_drive_toggled)

func is_grounded() -> bool:
	return grounded_check.button_pressed

func sync_title_ui() -> void:
	if _get_current_animation.is_null():
		return
	var anim_name: String = _get_current_animation.call()
	anim_title.text = anim_name.get_basename() if anim_name != "" else "None"
	if anim_name == "" or not _timeline or not _timeline.anim_player:
		return
	if not _timeline.anim_player.has_animation(anim_name):
		return
	var anim := _timeline.anim_player.get_animation(anim_name)
	var loop_enabled := anim.loop_mode != Animation.LOOP_NONE
	_syncing_timing = true
	for check in _loop_checks:
		check.set_pressed_no_signal(loop_enabled)
	var player_drive_enabled := _timeline.get_path_body_drive(anim_name) if _timeline else false
	for check in _player_drive_checks:
		check.set_pressed_no_signal(player_drive_enabled)
	_syncing_timing = false

func sync_ragdoll_toggles() -> void:
	if not _pose_controller:
		return
	_syncing_ragdoll = true
	for group in _ctrl_checks:
		var enabled := _pose_controller.is_group_controlled(group)
		for check: CheckBox in _ctrl_checks[group]:
			check.set_pressed_no_signal(enabled)
	var grounded_enabled := _pose_controller.is_pose_grounded()
	for check in _grounded_checks:
		check.set_pressed_no_signal(grounded_enabled)
	_syncing_ragdoll = false

func _notify_markers_changed() -> void:
	sync_ragdoll_toggles()
	if not _on_markers_changed.is_null():
		_on_markers_changed.call()

func _steps_to_time(steps: int) -> float:
	if not _timeline:
		return 0.0
	return maxi(0, steps - 1) * _timeline.step_duration

func _find_marker_by_name(marker_name: String) -> PoseMarker:
	if not _pose_controller:
		return null
	for m in _pose_controller.all_markers:
		if m.name == marker_name:
			return m
	return null

func _on_export_pressed() -> void:
	if _get_current_animation.is_null() or not _timeline:
		return
	var anim_name: String = _get_current_animation.call()
	if anim_name != "":
		_timeline.save_animation_to_disk(anim_name)

func _on_loop_toggled(enabled: bool) -> void:
	if _syncing_timing or _get_current_animation.is_null() or not _timeline or not _timeline.anim_player:
		return
	var anim_name: String = _get_current_animation.call()
	if anim_name == "" or not _timeline.anim_player.has_animation(anim_name):
		return
	var anim := _timeline.anim_player.get_animation(anim_name)
	anim.loop_mode = Animation.LOOP_LINEAR if enabled else Animation.LOOP_NONE
	_syncing_timing = true
	for check in _loop_checks:
		check.set_pressed_no_signal(enabled)
	_syncing_timing = false

func _on_player_drive_toggled(enabled: bool) -> void:
	if _syncing_timing or _get_current_animation.is_null() or not _timeline:
		return
	var anim_name: String = _get_current_animation.call()
	if anim_name == "":
		return
	_timeline.key_path_body_drive(anim_name, enabled)
	_syncing_timing = true
	for check in _player_drive_checks:
		check.set_pressed_no_signal(enabled)
	_syncing_timing = false
	player_drive_toggled.emit(enabled)
	if not _on_refresh_visuals.is_null():
		_on_refresh_visuals.call()

func _on_ctrl_group_toggled(group: String, enabled: bool) -> void:
	if _syncing_ragdoll or not _pose_controller:
		return
	_pose_controller.set_group_controlled(group, enabled)
	_notify_markers_changed()

func _on_grounded_toggled(enabled: bool) -> void:
	if _pose_controller:
		_pose_controller.set_pose_grounded(enabled)
	grounded_toggled.emit(enabled)

func _on_reset_pressed() -> void:
	if _anim_browser:
		_anim_browser.play_preview_animation(RESET_ANIM_NAME)

func _on_norm_horiz_pressed() -> void:
	if not _on_norm_horiz.is_null():
		_on_norm_horiz.call()

func _on_hang_pressed() -> void:
	if not _pose_controller:
		return
	var hang_marker := hang_control_marker if hang_control_marker else _find_marker_by_name("Crown")
	if not hang_marker:
		push_warning("PoseAssistantPanel: no hang control marker configured")
		return
	_pose_controller.set_hang_mode(hang_marker)
	_notify_markers_changed()

func _on_fall_pressed() -> void:
	if not _pose_controller:
		return
	_pose_controller.release_all_control()
	_notify_markers_changed()

func _on_clear_pressed() -> void:
	if _get_current_animation.is_null() or not _timeline:
		return
	var anim_name: String = _get_current_animation.call()
	if anim_name == "":
		return
	_timeline.clear_animation(anim_name)
	if not _on_refresh_visuals.is_null():
		_on_refresh_visuals.call()

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
	var steps := 8
	if _pose_controller and _pose_controller.pose_hud and _pose_controller.pose_hud.timeline_panel:
		steps = _pose_controller.pose_hud.timeline_panel.get_steps_value()
	var length := _steps_to_time(steps)
	if not _timeline.create_animation(anim_name, length):
		return
	if _anim_browser:
		_anim_browser.refresh_animation_list(anim_name)
	sync_title_ui()
	animation_created.emit(anim_name)

func _suggest_new_animation_name() -> String:
	if not _timeline or not _timeline.anim_player:
		return "pose_1"
	var index := 1
	while _timeline.anim_player.has_animation("pose_%d" % index):
		index += 1
	return "pose_%d" % index
