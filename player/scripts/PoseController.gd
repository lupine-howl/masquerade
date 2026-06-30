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
	# Only allow hotkeys if a marker is actually selected
	if not active_marker: return
	
	# 1. ESCAPE key to revert/cancel changes
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed):
		if active_marker.has_method("revert_to_original"):
			# This handles the physical move, UI cleanup, and fires 'deselected'
			active_marker.revert_to_original()
			get_viewport().set_input_as_handled()
			
	# 2. 'K' or 'I' key to manually commit/keyframe the pose
	elif event is InputEventKey and event.keycode == KEY_K and event.pressed:
		if pose_hud and pose_hud.has_method("_on_marker_save_requested"):
			# Force the HUD to process the save requested logic on the active marker
			pose_hud._on_marker_save_requested(active_marker)
			
			# After saving, tell the marker to clean up its orange visual state
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
