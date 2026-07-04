class_name PoseController
extends Node2D

signal active_marker_changed(marker: PoseMarker)
signal marker_list_ready(markers: Array[PoseMarker])

var active_markers: Array[PoseMarker] = []
var all_markers: Array[PoseMarker] = []

@export var player: CharacterBody2D
@export var pose_hud: PoseHUD

func get_primary_marker() -> PoseMarker:
	return active_markers.back() if not active_markers.is_empty() else null

func _ready() -> void:
	for child in get_children():
		if child is PoseMarker:
			all_markers.append(child)
			child.selected.connect(_on_marker_selected)
			child.deselected.connect(_on_marker_deselected)
			child.drag_ended.connect(_on_marker_drag_ended)
			child.dragged_position.connect(_on_marker_dragged_position.bind(child))
			child.dragged_rotation.connect(_on_marker_dragged_rotation.bind(child))

	marker_list_ready.emit(all_markers)

func _input(event: InputEvent) -> void:
	if not pose_hud:
		return

	var current_anim := pose_hud.get_current_animation()
	if current_anim == "" or not pose_hud.timeline:
		return

	var timeline := pose_hud.timeline
	var current_step := timeline.current_step
	var modifier_pressed: bool = event.is_command_or_control_pressed()
	var primary_marker := get_primary_marker()

	if event is InputEventKey and event.pressed and modifier_pressed:
		var shift_pressed := Input.is_key_pressed(KEY_SHIFT)
		var filter_path := ""

		if shift_pressed and primary_marker and timeline.anim_player:
			var root_node := timeline.anim_player.get_node(timeline.anim_player.root_node)
			filter_path = str(root_node.get_path_to(primary_marker))

		match event.keycode:
			KEY_Z:
				if not shift_pressed and not active_markers.is_empty():
					for m in active_markers:
						m.revert_to_original()
					get_viewport().set_input_as_handled()
				return
			KEY_C:
				timeline.copy_step_to_clipboard(current_anim, current_step, filter_path)
				get_viewport().set_input_as_handled()
				return
			KEY_X:
				timeline.copy_step_to_clipboard(current_anim, current_step, filter_path)
				timeline.delete_step_keyframes(current_anim, current_step, filter_path)
				pose_hud.reapply_current_step()
				get_viewport().set_input_as_handled()
				return
			KEY_V:
				filter_path = ""
				if shift_pressed and primary_marker and timeline.anim_player:
					var root_node := timeline.anim_player.get_node(timeline.anim_player.root_node)
					filter_path = str(root_node.get_path_to(primary_marker))
				timeline.paste_clipboard_to_step(current_anim, current_step, filter_path)
				pose_hud.reapply_current_step()
				get_viewport().set_input_as_handled()
				return
			KEY_DELETE, KEY_BACKSPACE:
				if shift_pressed:
					timeline.delete_step_keyframes(current_anim, current_step, filter_path)
					pose_hud.reapply_current_step()
					get_viewport().set_input_as_handled()
					return

	if event is InputEventKey and event.pressed and not modifier_pressed:
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			timeline.delete_step_keyframes(current_anim, current_step)
			pose_hud.reapply_current_step()
			get_viewport().set_input_as_handled()
			return

		elif event.keycode in [KEY_RIGHT, KEY_LEFT, KEY_UP, KEY_DOWN]:
			if pose_hud.is_posing() and not active_markers.is_empty():
				var shift_pressed := Input.is_key_pressed(KEY_SHIFT)
				var nudge_amt := 10.0 if shift_pressed else 1.0
				var motion := Vector2.ZERO
				match event.keycode:
					KEY_UP: motion.y = -nudge_amt
					KEY_DOWN: motion.y = nudge_amt
					KEY_LEFT: motion.x = -nudge_amt
					KEY_RIGHT: motion.x = nudge_amt
				for m in active_markers:
					m.global_position += motion
					pose_hud.request_auto_key(m)
				get_viewport().set_input_as_handled()
				return

		elif event.keycode == KEY_PERIOD:
			var total_steps := pose_hud.get_step_count()
			if total_steps == 0:
				return
			var next_step := clampi(timeline.current_step + 1, 0, total_steps - 1)
			timeline.set_step_selection([next_step])
			timeline.step_selection_anchor = next_step
			timeline.seek_step(next_step, current_anim)
			pose_hud.on_step_navigated()
			get_viewport().set_input_as_handled()
			return

		elif event.keycode == KEY_COMMA:
			var total_steps := pose_hud.get_step_count()
			if total_steps == 0:
				return
			var prev_step := clampi(timeline.current_step - 1, 0, total_steps - 1)
			timeline.set_step_selection([prev_step])
			timeline.step_selection_anchor = prev_step
			timeline.seek_step(prev_step, current_anim)
			pose_hud.on_step_navigated()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey and event.physical_keycode == KEY_K and event.pressed and not event.echo:
		pose_hud.key_all_markers()
		for m in all_markers:
			m._reset_marker_ui()
		pose_hud.refresh_timeline_visuals()
		get_viewport().set_input_as_handled()
		return

	if active_markers.is_empty():
		return

	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.physical_keycode == KEY_ESCAPE and event.pressed):
		for m in active_markers:
			m.revert_to_original()
		get_viewport().set_input_as_handled()

func _on_marker_dragged_position(delta: Vector2, source_marker: PoseMarker) -> void:
	for m in active_markers:
		if m != source_marker:
			m.constrain_global_position(m.global_position + delta)
			m._capture_original_state()

func _on_marker_dragged_rotation(delta_angle: float, source_marker: PoseMarker) -> void:
	for m in active_markers:
		if m != source_marker:
			if m.use_look_at:
				m.look_at_offset_deg += rad_to_deg(delta_angle)
			elif m.use_follow_rotation:
				m.follow_rotation_offset_deg += rad_to_deg(delta_angle)
			else:
				m.global_rotation += delta_angle
			m._capture_original_state()

func _on_marker_selected(marker: PoseMarker) -> void:
	var is_ctrl_pressed := Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
	if is_ctrl_pressed:
		if marker in active_markers:
			remove_marker_from_selection(marker)
		else:
			add_markers_to_selection([marker])
	else:
		set_active_markers([marker])

func set_active_markers(markers: Array[PoseMarker]) -> void:
	for m in active_markers:
		if m not in markers:
			m.set_active(false)
	active_markers = markers
	for m in active_markers:
		m.set_active(true)
	active_marker_changed.emit(get_primary_marker())

func add_markers_to_selection(markers: Array[PoseMarker]) -> void:
	for m in markers:
		if m not in active_markers:
			active_markers.append(m)
			m.set_active(true)
	active_marker_changed.emit(get_primary_marker())

func remove_marker_from_selection(marker: PoseMarker) -> void:
	if marker in active_markers:
		active_markers.erase(marker)
		marker.set_active(false)
		active_marker_changed.emit(get_primary_marker())

func _on_marker_deselected(_marker: PoseMarker) -> void:
	pass

func _on_marker_drag_ended(_marker: PoseMarker) -> void:
	if pose_hud and pose_hud.is_auto_recording():
		for m in active_markers:
			pose_hud.request_auto_key(m)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		set_active_markers([])

func toggle_controlled(is_controlled: bool) -> void:
	for m in active_markers:
		if is_controlled:
			m.take_control()
		else:
			m.release_control()

func toggle_follow_rotation(follow: bool) -> void:
	for m in active_markers:
		m.use_follow_rotation = follow

func swap_with_sibling(marker: PoseMarker) -> void:
	if not marker.sibling:
		return
	var sib := marker.sibling
	var orig_pos := marker.position
	marker.position = sib.position
	sib.position = orig_pos
	if marker.slave:
		marker.slave.global_position = marker.global_position
	if sib.slave:
		sib.slave.global_position = sib.global_position

func swap_all_siblings() -> void:
	var swapped: Dictionary = {}
	for marker in all_markers:
		if not marker.sibling or swapped.has(marker):
			continue
		var sib: PoseMarker = marker.sibling
		if swapped.has(sib):
			continue
		swap_with_sibling(marker)
		swapped[marker] = true
		swapped[sib] = true
