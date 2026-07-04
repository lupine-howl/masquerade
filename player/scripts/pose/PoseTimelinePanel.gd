class_name PoseTimelinePanel
extends VBoxContainer

signal playback_started
signal step_interacted(step: int)
signal visuals_refreshed

@onready var step_grid: Control = %StepGrid
@onready var btn_play: Button = %BtnPlay
@onready var btn_stop: Button = %BtnStop
@onready var btn_rewind: Button = %BtnRewind
@onready var btn_export: Button = %BtnExportAnimation
@onready var btn_reset: Button = %BtnReset
@onready var record_check: CheckBox = %RecordCheck
@onready var playback_controls: Control = %PlaybackControls
@onready var timecode_label: Label = %TimecodeLabel

var timeline: TimelineManager
var pose_controller: PoseController
var _get_anim_name: Callable

func setup(p_timeline: TimelineManager, p_controller: PoseController, get_anim_name: Callable) -> void:
	timeline = p_timeline
	pose_controller = p_controller
	_get_anim_name = get_anim_name

func _ready() -> void:
	record_check.button_pressed = false
	btn_play.pressed.connect(_on_play_pressed)
	btn_stop.pressed.connect(_on_stop_pressed)
	btn_rewind.pressed.connect(_on_rewind_pressed)
	btn_export.pressed.connect(_on_export_pressed)
	btn_reset.pressed.connect(_on_reset_pressed)

func is_recording() -> bool:
	return record_check.button_pressed

func get_step_count() -> int:
	return step_grid.get_child_count()

func set_recording(enabled: bool) -> void:
	record_check.button_pressed = enabled

func set_playback_controls_visible(show_controls: bool) -> void:
	if playback_controls:
		playback_controls.visible = show_controls

func build_step_grid(duration: float) -> void:
	if not timeline:
		return

	for child in step_grid.get_children():
		child.free()

	var num_steps := int(round(duration / timeline.step_duration)) + 1
	if num_steps < 1:
		num_steps = 1

	for i in range(num_steps):
		var step_rect := ColorRect.new()
		step_rect.custom_minimum_size = Vector2(20, 20)
		var is_dark_group := (i / 4) % 2 == 0
		var base_color := Color(0.2, 0.2, 0.2) if is_dark_group else Color(0.35, 0.35, 0.35)
		step_rect.color = base_color
		step_rect.set_meta("base_color", base_color)

		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(16, 16)
		dot.set_anchors_preset(Control.PRESET_CENTER)
		dot.grow_horizontal = Control.GROW_DIRECTION_BOTH
		dot.grow_vertical = Control.GROW_DIRECTION_BOTH
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.visible = false
		step_rect.add_child(dot)
		step_rect.gui_input.connect(_on_step_clicked.bind(i))
		step_grid.add_child(step_rect)

	update_grid_visuals()

func update_grid_visuals() -> void:
	if not timeline or _get_anim_name.is_null():
		return

	var anim_name: String = _get_anim_name.call()
	var primary_marker := pose_controller.get_primary_marker() if pose_controller else null
	var num_steps := step_grid.get_child_count()
	var visual_data := timeline.get_step_visual_data(anim_name, primary_marker, num_steps)

	for i in range(num_steps):
		var step_rect: ColorRect = step_grid.get_child(i)
		var dot = step_rect.get_child(0) if step_rect.get_child_count() > 0 else null

		if i == timeline.current_step:
			var physical_time := timeline.get_playback_time()
			var physical_step := int(round(physical_time / timeline.step_duration))
			step_rect.color = Color(0.3, 0.6, 1.0) if timeline.current_step == physical_step else Color(0.6, 0.3, 0.8)
		else:
			step_rect.color = step_rect.get_meta("base_color", Color(0.2, 0.2, 0.2))

		if not dot:
			continue

		var frame_data: Dictionary = visual_data[i]
		if frame_data["active"]:
			dot.visible = true
			dot.modulate = Color.RED
		elif frame_data["any"]:
			dot.visible = true
			dot.modulate = Color.WHITE
		else:
			dot.visible = false

	_update_timecode_label()
	visuals_refreshed.emit()

func sync_playback_step(is_posing: bool) -> void:
	if not timeline or not timeline.anim_player or not timeline.is_playback_active():
		return

	var playing_step := timeline.get_current_playback_step()
	var max_steps: int = max(0, step_grid.get_child_count() - 1)
	playing_step = clampi(playing_step, 0, max_steps)

	if timeline.current_step != playing_step:
		timeline.current_step = playing_step
		update_grid_visuals()
		if not is_posing:
			step_interacted.emit(playing_step)

func _update_timecode_label() -> void:
	if not timeline or not timecode_label:
		return
	var current_step_time := timeline.current_step * timeline.step_duration
	var whole_seconds := int(current_step_time)
	var milliseconds := int((current_step_time - whole_seconds) * 100)
	timecode_label.text = "%02d:%02d.%02d" % [whole_seconds / 60, whole_seconds % 60, milliseconds]

func _on_step_clicked(event: InputEvent, step_index: int) -> void:
	if pose_controller and pose_controller.player and not pose_controller.player.is_posing:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var anim_name: String = _get_anim_name.call() if not _get_anim_name.is_null() else ""
		if event.is_command_or_control_pressed():
			timeline.current_step = step_index
			if anim_name != "":
				timeline.seek_step(step_index, anim_name)
		else:
			timeline.seek_step(step_index, anim_name)
		update_grid_visuals()
		step_interacted.emit(step_index)

func _on_play_pressed() -> void:
	if _get_anim_name.is_null():
		return
	var anim_name: String = _get_anim_name.call()
	if anim_name != "" and timeline:
		playback_started.emit()
		timeline.play(anim_name)

func _on_stop_pressed() -> void:
	if timeline:
		timeline.pause()
		update_grid_visuals()

func _on_rewind_pressed() -> void:
	if timeline:
		var anim_name: String = _get_anim_name.call() if not _get_anim_name.is_null() else ""
		timeline.seek_step(0, anim_name)
	update_grid_visuals()

func _on_export_pressed() -> void:
	if _get_anim_name.is_null() or not timeline:
		return
	var anim_name: String = _get_anim_name.call()
	if anim_name != "":
		timeline.save_animation_to_disk(anim_name)

func _on_reset_pressed() -> void:
	if _get_anim_name.is_null() or not timeline:
		return
	timeline.clear_animation(_get_anim_name.call())
	update_grid_visuals()
