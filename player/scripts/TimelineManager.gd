class_name TimelineManager
extends Node

@export var anim_player: AnimationPlayer
@export var step_duration: float = 0.1

var current_step: int = 0

# Clipboard storage container for the copied frame payload
# Format: [{"path": NodePath, "value": Variant, "interpolation": int}]
var _clipboard_step_data: Array = []

func play(anim_name: String) -> void:
	if anim_player: anim_player.play(anim_name)

func stop() -> void:
	if anim_player: anim_player.stop()

func seek_step(step: int) -> void:
	current_step = step
	if anim_player:
		anim_player.seek(current_step * step_duration, true)

func get_animations() -> PackedStringArray:
	return anim_player.get_animation_list() if anim_player else PackedStringArray()

func set_length(anim_name: String, length: float) -> void:
	if anim_player and anim_player.has_animation(anim_name):
		anim_player.get_animation(anim_name).length = length

func clear_animation(anim_name: String) -> void:
	if anim_player and anim_player.has_animation(anim_name):
		anim_player.get_animation(anim_name).clear()

func get_current_playback_step() -> int:
	if not anim_player or not anim_player.is_playing(): 
		return current_step
	return int(round(anim_player.current_animation_position / step_duration))

# --- KEYFRAME MATH & SMART DELTA-KEYING ---

func key_property(anim_name: String, target_node: Node, property_suffix: String, value: Variant) -> void:
	if not anim_player or not anim_player.has_animation(anim_name) or not target_node: return
	
	var animation = anim_player.get_animation(anim_name)
	var root_node = anim_player.get_node(anim_player.root_node)
	var track_path = str(root_node.get_path_to(target_node)) + property_suffix
	
	var track_idx = animation.find_track(track_path, Animation.TYPE_VALUE)
	
	# RESOURCE DELTA CHECK
	if track_idx != -1 and animation.track_get_key_count(track_idx) > 0:
		var target_time = current_step * step_duration
		
		# Find the closest keyframe index at or near this step's time
		var key_idx = animation.track_find_key(track_idx, target_time, Animation.FIND_MODE_NEAREST)
		
		if key_idx != -1:
			# If the closest key returned is actually placed AHEAD of our current step time,
			# drop back an index to see what the value was BEFORE this moment on the timeline
			var key_time = animation.track_get_key_time(track_idx, key_idx)
			if key_time > target_time and key_idx > 0:
				key_idx -= 1
				
			var last_keyed_value = animation.track_get_key_value(track_idx, key_idx)
			
			# Precision approximation comparisons for math vectors/floats
			if typeof(value) == TYPE_FLOAT and abs(value - last_keyed_value) < 0.001:
				return
			elif typeof(value) == TYPE_VECTOR2 and value.is_equal_approx(last_keyed_value):
				return
			elif value == last_keyed_value:
				return

	# If it doesn't exist yet, append the track type dynamically
	if track_idx == -1:
		track_idx = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track_idx, track_path)
		
	if typeof(value) == TYPE_VECTOR2 or typeof(value) == TYPE_FLOAT:
		animation.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_LINEAR)
	
	animation.track_insert_key(track_idx, current_step * step_duration, value)

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
func copy_step_to_clipboard(anim_name: String, source_step: int) -> void:
	_clipboard_step_data.clear()
	if not anim_player or not anim_player.has_animation(anim_name): return
	
	var animation = anim_player.get_animation(anim_name)
	var source_time = source_step * step_duration
	var time_tolerance = 0.01
	
	for track_idx in animation.get_track_count():
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
				
	print("Copied ", _clipboard_step_data.size(), " tracks from step ", source_step)

## Deletes all keyframe data located exactly at a specific step index
func delete_step_keyframes(anim_name: String, step_index: int) -> void:
	if not anim_player or not anim_player.has_animation(anim_name): return
	var animation = anim_player.get_animation(anim_name)
	var target_time = step_index * step_duration
	var time_tolerance = 0.01
	
	for track_idx in animation.get_track_count():
		var key_idx = animation.track_find_key(track_idx, target_time, Animation.FIND_MODE_NEAREST)
		if key_idx != -1:
			var key_time = animation.track_get_key_time(track_idx, key_idx)
			if abs(key_time - target_time) <= time_tolerance:
				animation.track_remove_key(track_idx, key_idx)

# Inside TimelineManager.gd

## Keyframes the playback speed scale of the AnimationPlayer itself
func key_speed_scale(anim_name: String, speed_value: float) -> void:
	if not anim_player or not anim_player.has_animation(anim_name): return
	
	var animation = anim_player.get_animation(anim_name)
	var root_node = anim_player.get_node(anim_player.root_node)
	
	# Get the relative path from the root node back to the AnimationPlayer
	var player_path = str(root_node.get_path_to(anim_player)) + ":speed_scale"
	
	var track_idx = animation.find_track(player_path, Animation.TYPE_VALUE)

	# Create the track targeting the player if it doesn't exist
	if track_idx == -1:
		track_idx = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track_idx, player_path)
		# Speed updates usually look best with NEAREST or LINEAR interpolation
		animation.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_NEAREST)
	
	animation.track_insert_key(track_idx, 0.0, speed_value)
	print("Keyed speed_scale: ", speed_value, " at step ", current_step)

## Pastes the clipboard payload onto the designated target step index
func paste_clipboard_to_step(anim_name: String, target_step: int) -> void:
	if _clipboard_step_data.is_empty(): return
	if not anim_player or not anim_player.has_animation(anim_name): return
	
	var animation = anim_player.get_animation(anim_name)
	var target_time = target_step * step_duration
	
	# Wipe keys currently occupying the column to prevent data ghosts
	delete_step_keyframes(anim_name, target_step)
	
	# Reconstruct keys from clipboard data structures
	for track_data in _clipboard_step_data:
		var path = track_data["path"]
		var track_idx = animation.find_track(path, Animation.TYPE_VALUE)
		
		if track_idx == -1:
			track_idx = animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(track_idx, path)
			
		animation.track_set_interpolation_type(track_idx, track_data["interpolation"])
		animation.track_insert_key(track_idx, target_time, track_data["value"])
		
	print("Pasted ", _clipboard_step_data.size(), " tracks onto step ", target_step)

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
