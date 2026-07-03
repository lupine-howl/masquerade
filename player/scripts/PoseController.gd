class_name PoseController
extends Node2D

# Broadcasts state changes so the HUD can listen
signal active_marker_changed(marker: PoseMarker)
signal marker_list_ready(markers: Array[PoseMarker])

var active_markers: Array[PoseMarker] = []
var all_markers: Array[PoseMarker] = []

@export var player: CharacterBody2D 
@export var pose_hud: PoseHUD

# Helper to act as the "lead" marker for UI tracking
func get_primary_marker() -> PoseMarker:
	return active_markers.back() if not active_markers.is_empty() else null

func _ready() -> void:
	# Gather markers 
	for child in get_children():
		if child is PoseMarker:
			all_markers.append(child)
			
			child.selected.connect(_on_marker_selected)
			child.deselected.connect(_on_marker_deselected)
			child.drag_ended.connect(_on_marker_drag_ended)
			
			# Connect multi-drag synchronization signals
			child.dragged_position.connect(_on_marker_dragged_position.bind(child))
			child.dragged_rotation.connect(_on_marker_dragged_rotation.bind(child))
			
	# Tell the HUD the list is ready to be put in the dropdown
	marker_list_ready.emit(all_markers)

func _input(event: InputEvent) -> void:
	var current_anim = pose_hud._get_current_anim() if pose_hud else ""
	if current_anim == "" or not pose_hud.timeline: return
	
	var timeline = pose_hud.timeline
	var current_step = timeline.current_step
	var modifier_pressed = event.is_command_or_control_pressed()
	var primary_marker = get_primary_marker()
	
	# --- 1. GLOBAL / SELECTED TIMELINE CLIPBOARD HOTKEYS (Requires Ctrl/Cmd) ---
	if event is InputEventKey and event.pressed and modifier_pressed:
		var shift_pressed = Input.is_key_pressed(KEY_SHIFT)
		var filter_path = ""
		
		# If shift is pressed, calculate the specific track path prefix for the primary marker
		if shift_pressed and primary_marker and timeline.anim_player:
			var root_node = timeline.anim_player.get_node(timeline.anim_player.root_node)
			filter_path = str(root_node.get_path_to(primary_marker))
		
		match event.keycode:
			KEY_C:
				timeline.copy_step_to_clipboard(current_anim, current_step, filter_path)
				get_viewport().set_input_as_handled()
				return
				
			KEY_X:
				timeline.copy_step_to_clipboard(current_anim, current_step, filter_path)
				timeline.delete_step_keyframes(current_anim, current_step, filter_path)
				pose_hud._update_grid_visuals()
				get_viewport().set_input_as_handled()
				return
				
			KEY_V:
				filter_path = ""
				if shift_pressed and primary_marker and timeline.anim_player:
					var root_node = timeline.anim_player.get_node(timeline.anim_player.root_node)
					filter_path = str(root_node.get_path_to(primary_marker))
				
				timeline.paste_clipboard_to_step(current_anim, current_step, filter_path)
				pose_hud._update_grid_visuals()
				get_viewport().set_input_as_handled()
				return
								
			KEY_DELETE, KEY_BACKSPACE:
				if shift_pressed:
					timeline.delete_step_keyframes(current_anim, current_step, filter_path)
					pose_hud._update_grid_visuals()
					get_viewport().set_input_as_handled()
					return

	# --- 2. SINGLE-PRESS TIMELINE NAVIGATION & ACTIONS (No Ctrl/Cmd) ---
	if event is InputEventKey and event.pressed and not modifier_pressed:
		# Wipes all keyframes on this step entirely
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			timeline.delete_step_keyframes(current_anim, current_step)
			pose_hud._update_grid_visuals()
			get_viewport().set_input_as_handled()
			return
			
		# ARROW KEY NUDGING 
		elif event.keycode in [KEY_RIGHT, KEY_LEFT, KEY_UP, KEY_DOWN]:
			var is_posing = pose_hud.posing_check.button_pressed if pose_hud else false
			
			if is_posing and not active_markers.is_empty():
				var shift_pressed = Input.is_key_pressed(KEY_SHIFT)
				var nudge_amt = 10.0 if shift_pressed else 1.0 
				var motion = Vector2.ZERO
				
				match event.keycode:
					KEY_UP:    motion.y = -nudge_amt
					KEY_DOWN:  motion.y = nudge_amt
					KEY_LEFT:  motion.x = -nudge_amt
					KEY_RIGHT: motion.x = nudge_amt
					
				for m in active_markers:
					# 🆕 Directly apply motion to the offsets (the marker's physics process handles constraints natively!)
					m.offset_x += motion.x
					m.offset_y += motion.y
					
					if pose_hud and pose_hud.record_check.button_pressed:
						pose_hud._on_marker_save_requested(m)				
				get_viewport().set_input_as_handled()
				return
			
		elif event.keycode == KEY_PERIOD:
			var total_steps = pose_hud.step_grid.get_child_count() if pose_hud else 0
			if total_steps == 0: return
			var next_step = clampi(timeline.current_step + 1, 0, total_steps - 1)
			timeline.seek_step(next_step)
			pose_hud._update_grid_visuals()
			pose_hud._update_bone_info_checkboxes(primary_marker)
			get_viewport().set_input_as_handled()
			return
			
		elif event.keycode == KEY_COMMA:
			var total_steps = pose_hud.step_grid.get_child_count() if pose_hud else 0
			if total_steps == 0: return
			var next_step = clampi(timeline.current_step - 1, 0, total_steps - 1)
			timeline.seek_step(next_step)
			pose_hud._update_grid_visuals()
			pose_hud._update_bone_info_checkboxes(primary_marker)
			get_viewport().set_input_as_handled()
			return

	# --- 3. KEYFRAME & SELECTION HOTKEYS ---

	# 'K' key to manually commit a keyframe
	if event is InputEventKey and event.physical_keycode == KEY_K and event.pressed and not event.echo:
		if active_markers.is_empty():
			# Global Key All: If nothing is selected, K keys the entire body!
			if pose_hud and pose_hud.has_method("_on_key_all_pressed"):
				pose_hud._on_key_all_pressed()
		else:
			# Targeted Key: Bypasses the "Auto-Record" checkbox completely
			for m in active_markers:
				# 🆕 Key the custom offsets and configuration variables as the source of truth!
				timeline.key_property(current_anim, m, ":offset_x", m.offset_x)
				timeline.key_property(current_anim, m, ":offset_y", m.offset_y)
				timeline.key_property(current_anim, m, ":global_x", m.global_x)
				timeline.key_property(current_anim, m, ":global_y", m.global_y)
				
				if not m.follow_parent_rotation:
					timeline.key_property(current_anim, m, ":rotation_offset_deg", m.rotation_offset_deg)
					
				if m.has_method("_reset_marker_ui"):
					m._reset_marker_ui()
					
			if pose_hud:
				pose_hud._update_grid_visuals()
				
		get_viewport().set_input_as_handled()
		return

	# Only allow the ESCAPE key if we actively have limbs highlighted to cancel
	if active_markers.is_empty(): return
	
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.physical_keycode == KEY_ESCAPE and event.pressed):
		for m in active_markers:
			if m.has_method("revert_to_original"):
				m.revert_to_original()
		get_viewport().set_input_as_handled()

# --- MULTI-DRAG SYNC ---
func _on_marker_dragged_position(delta: Vector2, source_marker: PoseMarker) -> void:
	for m in active_markers:
		if m != source_marker:
			# 🆕 Adjust the offsets directly across the entire selected group
			m.offset_x += delta.x
			m.offset_y += delta.y
			m._capture_original_state()

func _on_marker_dragged_rotation(delta_angle: float, source_marker: PoseMarker) -> void:
	for m in active_markers:
		if m != source_marker:
			m.rotation_offset_deg += rad_to_deg(delta_angle)
			m._capture_original_state()

# --- SELECTION LOGIC ---
func _on_marker_selected(marker: PoseMarker) -> void:
	# Safely check global keyboard state for Ctrl (Win/Linux) or Cmd (Mac)
	var is_ctrl_pressed = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
	
	if is_ctrl_pressed:
		if marker in active_markers:
			remove_marker_from_selection(marker)
		else:
			add_markers_to_selection([marker])
	else:
		set_active_markers([marker])
		
func set_active_markers(markers: Array[PoseMarker]) -> void:
	# Deactivate old
	for m in active_markers:
		if m not in markers:
			m.set_active(false)
			
	active_markers = markers
	
	# Activate new
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
	pass # Handled safely by array filtering above

func _on_marker_drag_ended(marker: PoseMarker) -> void:
	if pose_hud and pose_hud.record_check.button_pressed:
		# Save all active markers when dragging ends for the group
		for m in active_markers:
			pose_hud._on_marker_save_requested(m)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		set_active_markers([])

# --- PUBLIC MUTATORS ---
func toggle_controlled(is_controlled: bool) -> void:
	for m in active_markers:
		if is_controlled: m.take_control()
		else: m.release_control()

func toggle_follow_rotation(follow: bool) -> void:
	for m in active_markers:
		m.follow_parent_rotation = follow

func toggle_freeze(freeze: bool) -> void:
	for m in active_markers:
		if m.slave:
			m.slave.freeze = freeze
			
func swap_with_sibling(marker: PoseMarker):
	if not marker.sibling: return
	
	# 🆕 Swap all the custom target variables instead of the final physical output
	var orig_off_x = marker.sibling.offset_x
	var orig_off_y = marker.sibling.offset_y
	var orig_rot = marker.sibling.rotation_offset_deg
	var orig_gx = marker.sibling.global_x
	var orig_gy = marker.sibling.global_y
	
	marker.sibling.offset_x = marker.offset_x
	marker.sibling.offset_y = marker.offset_y
	marker.sibling.rotation_offset_deg = marker.rotation_offset_deg
	marker.sibling.global_x = marker.global_x
	marker.sibling.global_y = marker.global_y
	
	marker.offset_x = orig_off_x
	marker.offset_y = orig_off_y
	marker.rotation_offset_deg = orig_rot
	marker.global_x = orig_gx
	marker.global_y = orig_gy
