class_name PoseController
extends Node2D

# 🆕 Broadcasts state changes so the HUD can listen
signal active_marker_changed(marker: PoseMarker)
signal marker_list_ready(markers: Array[PoseMarker])

var active_marker: PoseMarker = null
var all_markers: Array[PoseMarker] = []

@export var player: CharacterBody2D 
@export var pose_hud: PoseHUD

func _ready() -> void:
	# Gather markers (Assuming they are children, or you can use your group method)
	for child in get_children():
		if child is PoseMarker:
			all_markers.append(child)
			
			# Listen to the clean signals we set up in the marker
			child.selected.connect(_on_marker_selected)
			child.deselected.connect(_on_marker_deselected)
			child.drag_ended.connect(_on_marker_drag_ended)
			
	# Tell the HUD the list is ready to be put in the dropdown
	marker_list_ready.emit(all_markers)

func _input(event: InputEvent) -> void:
	# Fetch active context parameters safely out of the UI Layer
	var current_anim = pose_hud._get_current_anim() if pose_hud else ""
	if current_anim == "" or not pose_hud.timeline: return
	
	var timeline = pose_hud.timeline
	var current_step = timeline.current_step
	var modifier_pressed = event.is_command_or_control_pressed()
	
	# --- 1. GLOBAL / SELECTED TIMELINE CLIPBOARD HOTKEYS (Requires Ctrl/Cmd) ---
	if event is InputEventKey and event.pressed and modifier_pressed:
		var shift_pressed = Input.is_key_pressed(KEY_SHIFT)
		var filter_path = ""
		
		# If shift is pressed, calculate the specific track path prefix for the active marker
		if shift_pressed and active_marker and timeline.anim_player:
			var root_node = timeline.anim_player.get_node(timeline.anim_player.root_node)
			filter_path = str(root_node.get_path_to(active_marker))
		
		match event.keycode:
			KEY_C:
				# 📋 COPY (All tracks OR Filtered Node branch)
				timeline.copy_step_to_clipboard(current_anim, current_step, filter_path)
				get_viewport().set_input_as_handled()
				return
				
			KEY_X:
				# ✂️ CUT (All tracks OR Filtered Node branch)
				timeline.copy_step_to_clipboard(current_anim, current_step, filter_path)
				timeline.delete_step_keyframes(current_anim, current_step, filter_path)
				pose_hud._update_grid_visuals()
				get_viewport().set_input_as_handled()
				return
				
			KEY_V:
				# 📥 PASTE (Ctrl + V = standard paste | Ctrl + Shift + V = cross-node paste)
				filter_path = ""
				if shift_pressed and active_marker and timeline.anim_player:
					var root_node = timeline.anim_player.get_node(timeline.anim_player.root_node)
					filter_path = str(root_node.get_path_to(active_marker))
				
				# Pass the filter path into the updated execution statement
				timeline.paste_clipboard_to_step(current_anim, current_step, filter_path)
				pose_hud._update_grid_visuals()
				get_viewport().set_input_as_handled()
				return
								
			KEY_DELETE, KEY_BACKSPACE:
				# 🗑️ TARGETED DELETE (Ctrl + Shift + Delete clears only the active limb track)
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
			
		# 🆕 ARROW KEY NUDGING VS SCRUBBING
		elif event.keycode in [KEY_RIGHT, KEY_LEFT, KEY_UP, KEY_DOWN]:
			var is_posing = pose_hud.posing_check.button_pressed if pose_hud else false
			
			if is_posing and active_marker:
				# --- 🛠️ MODE A: NUDGE ACTIVE MARKER ---
				var nudge_amt = 1.0 # Adjust pixel distance per tap here
				var motion = Vector2.ZERO
				
				match event.keycode:
					KEY_UP:    motion.y = -nudge_amt
					KEY_DOWN:  motion.y = nudge_amt
					KEY_LEFT:  motion.x = -nudge_amt
					KEY_RIGHT: motion.x = nudge_amt
					
				# Apply position adjustment smoothly
				active_marker.global_position += motion
				
				# Force the marker to save the change if record mode is active
				if pose_hud and pose_hud.record_check.button_pressed:
					pose_hud._on_marker_save_requested(active_marker)
			else:
				# --- 🎞️ MODE B: SCRUB TIMELINE (Fallback when not posing) ---
				if event.keycode == KEY_UP or event.keycode == KEY_DOWN: return # Ignore vertical keys here
				
				var total_steps = pose_hud.step_grid.get_child_count() if pose_hud else 0
				if total_steps == 0: return
				
				var delta = 1 if event.keycode == KEY_RIGHT else -1
				var next_step = clampi(timeline.current_step + delta, 0, total_steps - 1)
				
				timeline.seek_step(next_step)
				pose_hud._update_grid_visuals()
				pose_hud._update_bone_info_checkboxes(active_marker)
				
			get_viewport().set_input_as_handled()
			return
			
		# --- Keep Comma/Period hotkeys dedicated strictly to frame stepping ---
		elif event.keycode == KEY_PERIOD:
			var total_steps = pose_hud.step_grid.get_child_count() if pose_hud else 0
			if total_steps == 0: return
			var next_step = clampi(timeline.current_step + 1, 0, total_steps - 1)
			timeline.seek_step(next_step)
			pose_hud._update_grid_visuals()
			pose_hud._update_bone_info_checkboxes(active_marker)
			get_viewport().set_input_as_handled()
			return
			
		elif event.keycode == KEY_COMMA:
			var total_steps = pose_hud.step_grid.get_child_count() if pose_hud else 0
			if total_steps == 0: return
			var next_step = clampi(timeline.current_step - 1, 0, total_steps - 1)
			timeline.seek_step(next_step)
			pose_hud._update_grid_visuals()
			pose_hud._update_bone_info_checkboxes(active_marker)
			get_viewport().set_input_as_handled()
			return
	# --- 2. SINGLE-PRESS DELETE HOTKEY (Must NOT have Ctrl/Cmd pressed) ---
	if event is InputEventKey and event.pressed and not modifier_pressed:
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			# Wipes all keyframes on this step entirely
			timeline.delete_step_keyframes(current_anim, current_step)
			pose_hud._update_grid_visuals()
			get_viewport().set_input_as_handled()
			return

	# --- 3. ACTIVE MARKER SELECTION HOTKEYS ---
	# Only allow the following filters if a physical limb marker is highlighted
	if not active_marker: return
	
	# ESCAPE key to revert/cancel changes
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed):
		if active_marker.has_method("revert_to_original"):
			active_marker.revert_to_original()
			get_viewport().set_input_as_handled()
			
	# 'K' key to manually commit/keyframe the active marker's pose
	elif event is InputEventKey and event.keycode == KEY_K and event.pressed:
		if pose_hud and pose_hud.has_method("_on_marker_save_requested"):
			pose_hud._on_marker_save_requested(active_marker)
			
			if active_marker.has_method("_reset_marker_ui"):
				active_marker._reset_marker_ui()
				
			get_viewport().set_input_as_handled()
									
func _on_marker_selected(marker: PoseMarker) -> void:
	set_active_marker(marker)

func _on_marker_deselected(marker: PoseMarker) -> void:
	if active_marker == marker:
		set_active_marker(null)

func _on_marker_drag_ended(marker: PoseMarker) -> void:
	# Check if the HUD exists and has record mode enabled
	if pose_hud and pose_hud.record_check.button_pressed:
		# Pass the marker directly to the HUD's save handler
		pose_hud._on_marker_save_requested(marker)

func set_active_marker(marker: PoseMarker) -> void:
	if active_marker == marker: return
	
	# Deactivate old marker
	if active_marker:
		active_marker.set_active(false)
		
	active_marker = marker
	
	# Activate new marker
	if active_marker:
		active_marker.set_active(true)
		
	# Broadcast to the HUD!
	active_marker_changed.emit(active_marker)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		set_active_marker(null)

# --- PUBLIC MUTATORS (The HUD calls these) ---

func toggle_controlled(is_controlled: bool) -> void:
	if active_marker:
		if is_controlled: active_marker.take_control()
		else: active_marker.release_control()

func toggle_follow_rotation(follow: bool) -> void:
	if active_marker:
		active_marker.follow_parent_rotation = follow

func toggle_freeze(freeze: bool) -> void:
	if active_marker and active_marker.slave:
		active_marker.slave.freeze = freeze
		
func swap_with_sibling(marker: PoseMarker):
	if not marker.sibling: return
	var original_sibling_pos = marker.sibling.global_position
	var original_sibling_rot = marker.sibling.global_rotation
	marker.sibling.global_rotation = marker.global_rotation
	marker.sibling.global_position = marker.global_position
	marker.global_position = original_sibling_pos
	marker.global_rotation = original_sibling_rot
