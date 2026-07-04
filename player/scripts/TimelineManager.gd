class_name TimelineManager
extends Node

signal playback_paused

@export var anim_player: AnimationPlayer
@export var step_duration: float = 0.1

var current_step: int = 0
var selected_steps: Array[int] = []
var step_selection_anchor: int = 0
var _playback_active: bool = false

# Clipboard storage container for the copied frame payload
# Format: [{"path": NodePath, "value": Variant, "interpolation": int}]
var _clipboard_step_data: Array = []

func _ready() -> void:
	if anim_player and not anim_player.animation_finished.is_connected(_on_animation_finished):
		anim_player.animation_finished.connect(_on_animation_finished)

func play(anim_name: String) -> void:
	if not anim_player:
		return
	_playback_active = true
	anim_player.speed_scale = get_speed_scale(anim_name)
	anim_player.play(anim_name)

func pause() -> void:
	if not anim_player:
		return
	_playback_active = false
	anim_player.pause()
	playback_paused.emit()

func stop() -> void:
	if not anim_player:
		return
	_playback_active = false
	anim_player.stop()
	playback_paused.emit()

func is_playback_active() -> bool:
	return _playback_active

func seek_step(step: int, anim_name: String = "", resume: bool = false) -> void:
	current_step = step
	if not anim_player:
		return
	var resolved: String = anim_name if anim_name != "" else String(anim_player.current_animation)
	if resolved == "" or not anim_player.has_animation(resolved):
		return
	var time := current_step * step_duration
	var should_resume := resume or _playback_active

	anim_player.speed_scale = get_speed_scale(resolved)
	if String(anim_player.current_animation) != resolved:
		anim_player.play(resolved)
	anim_player.seek(time, true)
	if should_resume:
		if not anim_player.is_playing():
			anim_player.play(resolved)
			anim_player.seek(time, true)
	else:
		anim_player.pause()
		_playback_active = false

func get_playback_time() -> float:
	if not anim_player:
		return current_step * step_duration
	if anim_player.current_animation != "":
		return anim_player.current_animation_position
	return current_step * step_duration

func get_animations() -> PackedStringArray:
	return anim_player.get_animation_list() if anim_player else PackedStringArray()

func set_length(anim_name: String, length: float) -> void:
	if anim_player and anim_player.has_animation(anim_name):
		anim_player.get_animation(anim_name).length = length

func clear_animation(anim_name: String) -> void:
	if anim_player and anim_player.has_animation(anim_name):
		anim_player.get_animation(anim_name).clear()

func get_current_playback_step() -> int:
	if not anim_player or not _playback_active or anim_player.current_animation == "":
		return current_step
	return int(round(anim_player.current_animation_position / step_duration))

func set_step_selection(steps: Array[int]) -> void:
	selected_steps = steps.duplicate()
	selected_steps.sort()
	if selected_steps.is_empty():
		selected_steps = [current_step]

func toggle_step_selected(step: int) -> void:
	if step in selected_steps:
		selected_steps.erase(step)
	else:
		selected_steps.append(step)
	if selected_steps.is_empty():
		selected_steps = [step]
	selected_steps.sort()

func select_step_range(from_step: int, to_step: int) -> void:
	var lo := mini(from_step, to_step)
	var hi := maxi(from_step, to_step)
	selected_steps.clear()
	for i in range(lo, hi + 1):
		selected_steps.append(i)

func is_step_selected(step: int) -> bool:
	if selected_steps.is_empty():
		return step == current_step
	return step in selected_steps

func get_key_target_steps() -> Array[int]:
	if selected_steps.is_empty():
		return [current_step]
	return selected_steps.duplicate()

func _on_animation_finished(anim_name: StringName) -> void:
	if not _playback_active or not anim_player:
		return
	var name_str := String(anim_name)
	if not anim_player.has_animation(name_str):
		return
	var anim := anim_player.get_animation(name_str)
	if anim.loop_mode == Animation.LOOP_NONE:
		pause()

# --- KEYFRAME MATH & SMART DELTA-KEYING ---

func key_property(anim_name: String, target_node: Node, property_suffix: String, value: Variant) -> void:
	var previous_step := current_step
	for step in get_key_target_steps():
		current_step = step
		_key_property_at_current_step(anim_name, target_node, property_suffix, value)
	current_step = previous_step

func _key_property_at_current_step(anim_name: String, target_node: Node, property_suffix: String, value: Variant) -> void:
	if not anim_player or not anim_player.has_animation(anim_name) or not target_node:
		return

	var animation := anim_player.get_animation(anim_name)
	var root_node := anim_player.get_node(anim_player.root_node)
	var track_path := str(root_node.get_path_to(target_node)) + property_suffix
	var target_time := current_step * step_duration

	var track_idx := animation.find_track(track_path, Animation.TYPE_VALUE)
	if track_idx != -1:
		var prior_value: Variant = _get_prior_key_value(animation, track_idx, target_time)
		if prior_value != null and _values_equal(value, prior_value):
			_remove_exact_key_at_time(animation, track_idx, target_time)
			return

		var existing_idx := _find_exact_key_index(animation, track_idx, target_time)
		if existing_idx != -1:
			animation.track_set_key_value(track_idx, existing_idx, value)
			return

	if track_idx == -1:
		track_idx = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track_idx, track_path)

	if typeof(value) == TYPE_VECTOR2 or typeof(value) == TYPE_FLOAT:
		animation.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_LINEAR)
	elif typeof(value) == TYPE_BOOL:
		animation.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_NEAREST)

	animation.track_insert_key(track_idx, target_time, value)

func _values_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_FLOAT and typeof(b) == TYPE_FLOAT:
		return abs(a - b) < 0.001
	if typeof(a) == TYPE_VECTOR2 and typeof(b) == TYPE_VECTOR2:
		return a.is_equal_approx(b)
	return a == b

func _get_prior_key_value(animation: Animation, track_idx: int, target_time: float) -> Variant:
	if animation.track_get_key_count(track_idx) == 0:
		return null
	var key_idx := animation.track_find_key(track_idx, target_time, Animation.FIND_MODE_NEAREST)
	if key_idx == -1:
		return null
	var key_time := animation.track_get_key_time(track_idx, key_idx)
	if key_time > target_time + 0.01:
		if key_idx == 0:
			return null
		key_idx -= 1
	elif abs(key_time - target_time) <= 0.01:
		if key_idx == 0:
			return null
		key_idx -= 1
	return animation.track_get_key_value(track_idx, key_idx)

func _find_exact_key_index(animation: Animation, track_idx: int, target_time: float) -> int:
	var key_idx := animation.track_find_key(track_idx, target_time, Animation.FIND_MODE_NEAREST)
	if key_idx == -1:
		return -1
	if abs(animation.track_get_key_time(track_idx, key_idx) - target_time) <= 0.01:
		return key_idx
	return -1

func _remove_exact_key_at_time(animation: Animation, track_idx: int, target_time: float) -> void:
	var key_idx := _find_exact_key_index(animation, track_idx, target_time)
	if key_idx != -1:
		animation.track_remove_key(track_idx, key_idx)

## Ensures is_controlled has a step-0 baseline; keys the current step when control differs from that baseline.
func ensure_marker_control_keyed(anim_name: String, marker: PoseMarker) -> void:
	if not marker:
		return
	var value := marker.is_controlled
	if not _has_exact_key_at_step(anim_name, marker, ":is_controlled", 0):
		_insert_key_at_step(anim_name, marker, ":is_controlled", value, 0)
	elif _get_exact_key_value_at_step(anim_name, marker, ":is_controlled", 0) != value:
		_insert_key_at_step(anim_name, marker, ":is_controlled", value, current_step)

## Keys is_controlled at target steps when toggled; step 0 keeps the pre-toggle value if unset.
func key_marker_controlled(anim_name: String, marker: PoseMarker, previous_value: bool) -> void:
	if not marker:
		return
	if not _has_exact_key_at_step(anim_name, marker, ":is_controlled", 0):
		_insert_key_at_step(anim_name, marker, ":is_controlled", previous_value, 0)
	var previous_step := current_step
	for step in get_key_target_steps():
		current_step = step
		_key_property_at_current_step(anim_name, marker, ":is_controlled", marker.is_controlled)
	current_step = previous_step

## Keys local position and constraint mode; rotation is driven by constraints at runtime.
func key_marker_pose(anim_name: String, marker: PoseMarker) -> void:
	if not marker:
		return
	ensure_marker_control_keyed(anim_name, marker)
	_remove_legacy_global_pose_tracks(anim_name, marker)
	_remove_legacy_rotation_pose_tracks(anim_name, marker)
	var previous_step := current_step
	for step in get_key_target_steps():
		current_step = step
		_key_property_at_current_step(anim_name, marker, ":position", marker.position)
		_key_property_at_current_step(anim_name, marker, ":use_look_at", marker.use_look_at)
		_key_property_at_current_step(anim_name, marker, ":use_follow_rotation", marker.use_follow_rotation)
	current_step = previous_step

func remove_marker_pose_keys(anim_name: String, marker: PoseMarker) -> void:
	if not marker:
		return
	remove_keyframe(anim_name, marker, ":position")
	remove_keyframe(anim_name, marker, ":rotation")
	remove_keyframe(anim_name, marker, ":global_position")
	remove_keyframe(anim_name, marker, ":global_rotation")
	remove_keyframe(anim_name, marker, ":use_look_at")
	remove_keyframe(anim_name, marker, ":use_follow_rotation")
	remove_keyframe(anim_name, marker, ":look_at_offset_deg")
	remove_keyframe(anim_name, marker, ":follow_rotation_offset_deg")

func _remove_legacy_global_pose_tracks(anim_name: String, marker: PoseMarker) -> void:
	if not anim_player or not anim_player.has_animation(anim_name) or not marker:
		return
	var animation := anim_player.get_animation(anim_name)
	var root_node := anim_player.get_node(anim_player.root_node)
	var base_path := str(root_node.get_path_to(marker))
	for legacy_suffix in [":global_position", ":global_rotation"]:
		var track_idx := animation.find_track(base_path + legacy_suffix, Animation.TYPE_VALUE)
		if track_idx != -1:
			animation.remove_track(track_idx)

func _remove_legacy_rotation_pose_tracks(anim_name: String, marker: PoseMarker) -> void:
	if not anim_player or not anim_player.has_animation(anim_name) or not marker:
		return
	var animation := anim_player.get_animation(anim_name)
	var root_node := anim_player.get_node(anim_player.root_node)
	var base_path := str(root_node.get_path_to(marker))
	for legacy_suffix in [":rotation", ":look_at_offset_deg", ":follow_rotation_offset_deg"]:
		var track_idx := animation.find_track(base_path + legacy_suffix, Animation.TYPE_VALUE)
		if track_idx != -1:
			animation.remove_track(track_idx)

func _insert_key_at_step(
	anim_name: String,
	target_node: Node,
	property_suffix: String,
	value: Variant,
	step: int
) -> void:
	var previous_step := current_step
	current_step = step
	_key_property_at_current_step(anim_name, target_node, property_suffix, value)
	current_step = previous_step

func _has_exact_key_at_step(
	anim_name: String,
	target_node: Node,
	property_suffix: String,
	step: int
) -> bool:
	return _get_exact_key_value_at_step(anim_name, target_node, property_suffix, step) != null

func _get_exact_key_value_at_step(
	anim_name: String,
	target_node: Node,
	property_suffix: String,
	step: int
) -> Variant:
	if not anim_player or not anim_player.has_animation(anim_name) or not target_node:
		return null
	var animation := anim_player.get_animation(anim_name)
	var root_node := anim_player.get_node(anim_player.root_node)
	var track_path := str(root_node.get_path_to(target_node)) + property_suffix
	var track_idx := animation.find_track(track_path, Animation.TYPE_VALUE)
	if track_idx == -1:
		return null
	var target_time := step * step_duration
	var key_idx := animation.track_find_key(track_idx, target_time, Animation.FIND_MODE_NEAREST)
	if key_idx == -1:
		return null
	if abs(animation.track_get_key_time(track_idx, key_idx) - target_time) > 0.01:
		return null
	return animation.track_get_key_value(track_idx, key_idx)

func remove_keyframe(anim_name: String, target_node: Node, property_suffix: String) -> void:
	if not anim_player or not anim_player.has_animation(anim_name) or not target_node: return
	
	var animation = anim_player.get_animation(anim_name)
	var root_node = anim_player.get_node(anim_player.root_node)
	var track_path = str(root_node.get_path_to(target_node)) + property_suffix
	
	var track_idx = animation.find_track(track_path, Animation.TYPE_VALUE)
	if track_idx != -1:
		var target_time = current_step * step_duration
		var key_idx = animation.track_find_key(track_idx, target_time, Animation.FIND_MODE_NEAREST)
		
		if key_idx != -1:
			var key_time = animation.track_get_key_time(track_idx, key_idx)
			if abs(key_time - target_time) <= 0.01:
				animation.track_remove_key(track_idx, key_idx)

# --- CLIPBOARD OPERATIONS (COPY / CUT / PASTE) ---

## Captures all keyframe data located exactly at a specific step index across all tracks
# Inside TimelineManager.gd

## Captures keyframe data at a specific step. If filter_path is provided, only copies tracks starting with that path.
func copy_step_to_clipboard(anim_name: String, source_step: int, filter_path: String = "") -> void:
	_clipboard_step_data.clear()
	if not anim_player or not anim_player.has_animation(anim_name): return
	
	var animation = anim_player.get_animation(anim_name)
	var source_time = source_step * step_duration
	var time_tolerance = 0.01
	
	for track_idx in animation.get_track_count():
		var track_path_str = str(animation.track_get_path(track_idx))
		
		# 🆕 FILTER: Skip if we are targeting a single part and this track doesn't match
		if filter_path != "" and not track_path_str.begins_with(filter_path):
			continue
			
		var key_idx = animation.track_find_key(track_idx, source_time, Animation.FIND_MODE_NEAREST)
		if key_idx != -1:
			var key_time = animation.track_get_key_time(track_idx, key_idx)
			if abs(key_time - source_time) <= time_tolerance:
				var track_data = {
					"path": animation.track_get_path(track_idx),
					"value": animation.track_get_key_value(track_idx, key_idx),
					"interpolation": animation.track_get_interpolation_type(track_idx)
				}
				_clipboard_step_data.append(track_data)
				
	print("Copied ", _clipboard_step_data.size(), " tracks from step ", source_step, " (Filter: ", filter_path if filter_path != "" else "All", ")")

## Deletes keyframe data at a specific step. Can be filtered to a single target node path.
func delete_step_keyframes(anim_name: String, step_index: int, filter_path: String = "") -> void:
	if not anim_player or not anim_player.has_animation(anim_name): return
	var animation = anim_player.get_animation(anim_name)
	var target_time = step_index * step_duration
	var time_tolerance = 0.01
	
	for track_idx in animation.get_track_count():
		var track_path_str = str(animation.track_get_path(track_idx))
		
		# 🆕 FILTER: Skip if we are deleting a single part and this track doesn't match
		if filter_path != "" and not track_path_str.begins_with(filter_path):
			continue
			
		var key_idx = animation.track_find_key(track_idx, target_time, Animation.FIND_MODE_NEAREST)
		if key_idx != -1:
			var key_time = animation.track_get_key_time(track_idx, key_idx)
			if abs(key_time - target_time) <= time_tolerance:
				animation.track_remove_key(track_idx, key_idx)
				
## Keyframes playback speed on frame 1 (step 0) of the given animation.
func key_speed_scale(anim_name: String, speed_value: float) -> void:
	if not anim_player or not anim_player.has_animation(anim_name):
		return

	var animation := anim_player.get_animation(anim_name)
	var track_idx := _find_speed_scale_track(animation)
	if track_idx == -1:
		track_idx = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track_idx, _speed_scale_track_path())
		animation.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_NEAREST)

	var key_time := 0.0
	var key_idx := animation.track_find_key(track_idx, key_time, Animation.FIND_MODE_NEAREST)
	if key_idx != -1 and abs(animation.track_get_key_time(track_idx, key_idx) - key_time) <= 0.01:
		animation.track_set_key_value(track_idx, key_idx, speed_value)
	else:
		animation.track_insert_key(track_idx, key_time, speed_value)

	_persist_animation(anim_name)

func get_speed_scale(anim_name: String) -> float:
	if not anim_player or not anim_player.has_animation(anim_name):
		return 1.0
	if anim_player is PlayerAnimator:
		return (anim_player as PlayerAnimator).read_speed_scale_key(anim_name)
	var animation := anim_player.get_animation(anim_name)
	var track_idx := _find_speed_scale_track(animation)
	if track_idx == -1:
		return 1.0
	var key_idx := animation.track_find_key(track_idx, 0.0, Animation.FIND_MODE_NEAREST)
	if key_idx == -1 or abs(animation.track_get_key_time(track_idx, key_idx)) > 0.01:
		return 1.0
	return float(animation.track_get_key_value(track_idx, key_idx))

func _speed_scale_track_path() -> NodePath:
	if not anim_player:
		return NodePath()
	var root_node := anim_player.get_node(anim_player.root_node)
	return NodePath(str(root_node.get_path_to(anim_player)) + ":speed_scale")

func _find_speed_scale_track(animation: Animation) -> int:
	var track_idx := animation.find_track(_speed_scale_track_path(), Animation.TYPE_VALUE)
	if track_idx != -1:
		return track_idx
	for i in animation.get_track_count():
		if str(animation.track_get_path(i)).ends_with(":speed_scale"):
			return i
	return -1

func _persist_animation(anim_name: String) -> void:
	var anim_resource: Animation = anim_player.get_animation(anim_name)
	var path := anim_resource.resource_path
	if path != "" and not path.begins_with("local://"):
		ResourceSaver.save(anim_resource, path)

## Pastes the clipboard payload onto the target step. 
## If override_target_path is provided, redirects the tracks to target that node instead.
func paste_clipboard_to_step(anim_name: String, target_step: int, override_target_path: String = "") -> void:
	if _clipboard_step_data.is_empty(): return
	if not anim_player or not anim_player.has_animation(anim_name): return
	
	var animation = anim_player.get_animation(anim_name)
	var target_time = target_step * step_duration
	
	# If we are doing a targeted paste onto a different limb, only wipe out 
	# the destination tracks for THAT specific limb on this frame
	delete_step_keyframes(anim_name, target_step, override_target_path)
	
	for track_data in _clipboard_step_data:
		var original_path: NodePath = track_data["path"]
		var target_path: NodePath = original_path
		
		# 🆕 CROSS-NODE REDIRECTION LOGIC
		if override_target_path != "":
			# Extract the property segment (e.g., ":position" or ":rotation")
			var property_suffix = ""
			var path_string = str(original_path)
			var colon_idx = path_string.find(":")
			if colon_idx != -1:
				property_suffix = path_string.substr(colon_idx)
				
			# Splice the new target node path together with the old property rules
			target_path = NodePath(override_target_path + property_suffix)
		
		var track_idx = animation.find_track(target_path, Animation.TYPE_VALUE)
		if track_idx == -1:
			track_idx = animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(track_idx, target_path)
			
		animation.track_set_interpolation_type(track_idx, track_data["interpolation"])
		animation.track_insert_key(track_idx, target_time, track_data["value"])
		
	print("Pasted ", _clipboard_step_data.size(), " tracks onto path: ", override_target_path if override_target_path != "" else "Original Tracks")
	
# --- UI SEQUENCER GRAPHICS PIPELINE ---

# Used by the HUD to figure out where to draw the red/white dots
func get_step_visual_data(anim_name: String, active_marker: Node, total_steps: int) -> Array:
	var result = []
	if not anim_player or not anim_player.has_animation(anim_name):
		for i in range(total_steps): result.append({"any": false, "active": false})
		return result
		
	var animation = anim_player.get_animation(anim_name)
	var active_path = ""
	if active_marker:
		var root_node = anim_player.get_node(anim_player.root_node)
		active_path = str(root_node.get_path_to(active_marker))

	for i in range(total_steps):
		var target_time = i * step_duration
		var has_any = false
		var has_active = false
		
		for track_idx in animation.get_track_count():
			var key_idx = animation.track_find_key(track_idx, target_time, Animation.FIND_MODE_NEAREST)
			if key_idx != -1:
				if abs(animation.track_get_key_time(track_idx, key_idx) - target_time) <= 0.01:
					has_any = true
					var track_path_str = str(animation.track_get_path(track_idx))
					if active_path != "" and track_path_str.begins_with(active_path):
						has_active = true
						break
		result.append({"any": has_any, "active": has_active})
	return result

# --- FILE SYSTEM IO OPERATIONS ---

## Saves a specific animation resource back to a given file path
func save_animation_to_disk(anim_name: String, custom_path: String = "") -> void:
	if not anim_player or not anim_player.has_animation(anim_name): 
		push_error("Animation not found: " + anim_name)
		return
		
	var anim_resource: Animation = anim_player.get_animation(anim_name)
	var path = custom_path if custom_path != "" else anim_resource.resource_path
	
	if path == "" or path.begins_with("local://"):
		path = "res://animations/" + anim_name + ".tres"
		
	var dir = DirAccess.open("res://")
	if not dir.dir_exists(path.get_base_dir()):
		dir.make_dir_recursive(path.get_base_dir())
		
	var error = ResourceSaver.save(anim_resource, path)
	if error == OK:
		print("Successfully saved animation out-of-game to: ", path)
	else:
		push_error("Failed to save animation resource. Error code: ", error)
