class_name PoseAnimBrowser
extends PanelContainer

signal animation_changed(anim_name: String)
signal duration_changed(duration: float)
signal speed_changed(speed: float)

@onready var anim_strip: VBoxContainer = %AnimStrip

var timeline: TimelineManager
var _anim_buttons: Dictionary = {}
var _anim_order: Array[String] = []
var _current_anim: String = ""
var _display_sync_only: bool = false
var _preview_active: bool = false
var _preview_anim_name: String = ""
var _preview_return_anim: String = ""
var _preview_return_step: int = 0

func setup(p_timeline: TimelineManager) -> void:
	timeline = p_timeline
	if timeline and timeline.anim_player and not timeline.anim_player.animation_finished.is_connected(_on_anim_player_finished):
		timeline.anim_player.animation_finished.connect(_on_anim_player_finished)

func _ready() -> void:
	_style_tab_strip()

func is_preview_active() -> bool:
	return _preview_active

func play_preview_animation(preview_name: String) -> void:
	if not timeline or not timeline.anim_player or not timeline.anim_player.has_animation(preview_name):
		return
	_preview_return_anim = get_current_animation()
	_preview_return_step = timeline.current_step
	_preview_anim_name = preview_name
	_preview_active = true
	timeline.stop()
	timeline.anim_player.play(preview_name)

func refresh_animation_list(select_name: String = "") -> void:
	populate_animations()
	if select_name != "":
		select_animation_by_name(select_name)

func apply_steps_to_current_animation(steps: int) -> void:
	var anim_name := get_current_animation()
	if anim_name == "" or not timeline:
		return
	var next_time := steps_to_time(steps)
	timeline.set_length(anim_name, next_time)
	duration_changed.emit(next_time)

func apply_speed_to_current_animation(speed: float) -> void:
	var anim_name := get_current_animation()
	if anim_name == "" or not timeline:
		return
	timeline.key_speed_scale(anim_name, speed)
	if timeline.anim_player:
		timeline.anim_player.speed_scale = speed
	speed_changed.emit(speed)

func sync_timing_ui_for_current_animation() -> void:
	pass

func _on_anim_player_finished(anim_name: StringName) -> void:
	if not _preview_active or String(anim_name) != _preview_anim_name:
		return
	_preview_active = false
	if timeline:
		timeline.seek_step(_preview_return_step, _preview_return_anim)

func get_animation_names() -> Array[String]:
	return _anim_order.duplicate()

func get_current_animation() -> String:
	return _current_anim

func time_to_steps(duration_seconds: float) -> int:
	if not timeline or timeline.step_duration <= 0:
		return 0
	return int(round(duration_seconds / timeline.step_duration))

func steps_to_time(steps: int) -> float:
	if not timeline:
		return 0.0
	return steps * timeline.step_duration

func populate_animations() -> void:
	for child in anim_strip.get_children():
		child.queue_free()
	_anim_buttons.clear()
	_anim_order.clear()
	_current_anim = ""
	if not timeline:
		return
	for anim_name in timeline.get_animations():
		_anim_order.append(anim_name)
		var btn := PoseTabStyles.make_tab_button(anim_name.get_basename(), anim_name)
		btn.gui_input.connect(_on_anim_tab_gui_input.bind(anim_name))
		_apply_tab_style(btn, false)
		anim_strip.add_child(btn)
		_anim_buttons[anim_name] = btn
	if not _anim_order.is_empty():
		_select_animation(_anim_order[0], false)

func select_animation_by_name(anim_name: String) -> void:
	if anim_name == _current_anim:
		return
	_select_animation(anim_name, true)

func sync_display_to_animation(anim_name: String) -> void:
	if anim_name == "":
		return
	_display_sync_only = true
	_highlight_animation(anim_name)
	_current_anim = anim_name
	_display_sync_only = false

func _select_animation(anim_name: String, emit_signal: bool) -> void:
	if not _anim_buttons.has(anim_name):
		return
	var was_playing := false
	if timeline and timeline.anim_player:
		was_playing = timeline.anim_player.is_playing()
		if was_playing:
			timeline.stop()
	_current_anim = anim_name
	_highlight_animation(anim_name)
	if emit_signal and not _display_sync_only:
		if timeline and timeline.anim_player and timeline.anim_player.has_animation(anim_name):
			var anim := timeline.anim_player.get_animation(anim_name)
			duration_changed.emit(anim.length)
			var speed := timeline.get_speed_scale(anim_name)
			timeline.anim_player.speed_scale = speed
			speed_changed.emit(speed)
		animation_changed.emit(anim_name)
		if was_playing and timeline:
			timeline.play(anim_name)

func _highlight_animation(anim_name: String) -> void:
	for name in _anim_buttons:
		_apply_tab_style(_anim_buttons[name], name == anim_name)

func _on_anim_tab_gui_input(event: InputEvent, anim_name: String) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	_select_animation(anim_name, true)
	get_viewport().set_input_as_handled()

func _style_tab_strip() -> void:
	PoseTabStyles.apply_left_tab_strip(self)
	PoseTabStyles.configure_strip_container(anim_strip)

func _apply_tab_style(btn: Button, selected: bool) -> void:
	PoseTabStyles.apply_tab_button(btn, selected, false)
