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

# Inside PoseController.gd

func _input(event: InputEvent) -> void:
	# Fetch active context parameters safely out of the UI Layer
	var current_anim = pose_hud._get_current_anim() if pose_hud else ""
	if current_anim == "" or not pose_hud.timeline: return
	
	var timeline = pose_hud.timeline
	var current_step = timeline.current_step
	var modifier_pressed = event.is_command_or_control_pressed()
	
	# --- 1. GLOBAL TIMELINE CLIPBOARD HOTKEYS (Requires Ctrl/Cmd) ---
	if event is InputEventKey and event.pressed and modifier_pressed:
		match event.keycode:
			KEY_C:
				timeline.copy_step_to_clipboard(current_anim, current_step)
				get_viewport().set_input_as_handled()
				return
				
			KEY_X:
				timeline.copy_step_to_clipboard(current_anim, current_step)
				timeline.delete_step_keyframes(current_anim, current_step)
				pose_hud._update_grid_visuals()
				get_viewport().set_input_as_handled()
				return
				
			KEY_V:
				timeline.paste_clipboard_to_step(current_anim, current_step)
				pose_hud._update_grid_visuals()
				get_viewport().set_input_as_handled()
				return

	# --- 2. SINGLE-PRESS DELETE HOTKEY (Must NOT have Ctrl/Cmd pressed) ---
	if event is InputEventKey and event.pressed and not modifier_pressed:
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
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
