class_name PoseHUD
extends CanvasLayer

signal playback_started

# 🆕 The two pillars of our new architecture
@export var pose_controller: PoseController 
@export var timeline: TimelineManager

# --- UI References ---
@onready var anim_dropdown: OptionButton = %AnimDropdown
@onready var speed_box: SpinBox = %SpeedSpinBox
@onready var duration_box: SpinBox = %DurationSpinBox
@onready var step_grid: Control = %StepGrid 
@onready var btn_play: Button = %BtnPlay
@onready var btn_stop: Button = %BtnStop
@onready var btn_rewind: Button = %BtnRewind
@onready var btn_export: Button = %BtnExportAnimation

@onready var pos_label: Label = %PosLabel
@onready var rot_label: Label = %RotLabel

# Checkboxes & Keying Buttons
@onready var controlled_check: CheckBox = %ControlledCheck
@onready var follow_rotation_check: CheckBox = %FollowRotationCheck
@onready var freeze_check: CheckBox = %FreezeCheck
@onready var record_check: CheckBox = %RecordCheck
@onready var posing_check: CheckBox = %PosingCheck

@onready var btn_key_position: Button = %BtnKeyPos
@onready var btn_reset_position: Button = %BtnResetPos
@onready var btn_key_rotation: Button = %BtnKeyRot
@onready var btn_reset_rotation: Button = %BtnResetRot
@onready var btn_key_controlled: Button = %BtnKeyControlled
@onready var btn_key_follow_rotation: = %BtnKeyFollowRotation
@onready var btn_key_freeze: Button = %BtnKeyFreeze
@onready var btn_key_all: Button = %BtnKeyAll
@onready var btn_reset: Button = %BtnReset
@onready var btn_swap_sibling: Button = %BtnSwapSibling

@onready var playback_controls_container: Control = %PlaybackControls

func _ready() -> void:
	record_check.button_pressed = true
	posing_check.button_pressed = true
	
	if pose_controller:
		pose_controller.active_marker_changed.connect(_on_active_marker_changed)
	
	controlled_check.toggled.connect(_on_controlled_toggled)
	follow_rotation_check.toggled.connect(_on_rotation_toggled)
	freeze_check.toggled.connect(_on_freeze_toggled)
	posing_check.toggled.connect(_on_pose_toggled)
	
	pose_controller.marker_list_ready.connect(_setup_part_table)
	
	btn_key_controlled.pressed.connect(_on_key_controlled_pressed)
	btn_key_follow_rotation.pressed.connect(_on_key_follow_rotation_pressed)
	btn_key_freeze.pressed.connect(_on_key_freeze_pressed)
	btn_key_position.pressed.connect(_on_key_position_pressed)
	btn_key_rotation.pressed.connect(_on_key_rotation_pressed)
	btn_key_all.pressed.connect(_on_key_all_pressed)
	btn_reset_position.pressed.connect(_on_reset_position_pressed)
	btn_reset_rotation.pressed.connect(_on_reset_rotation_pressed)
	btn_export.pressed.connect(_on_export_pressed)
	btn_swap_sibling.pressed.connect(_on_swap_sibling_pressed)
	
	
	
	btn_play.pressed.connect(_on_play_pressed)
	btn_stop.pressed.connect(_on_stop_pressed)
	btn_rewind.pressed.connect(_on_rewind_pressed)
	btn_reset.pressed.connect(_on_reset_pressed)
	speed_box.value_changed.connect(_on_speed_box_changed)
	duration_box.value_changed.connect(_on_duration_changed)
	anim_dropdown.item_selected.connect(_on_animation_changed)
	
	_populate_animations()
	if timeline and anim_dropdown.item_count > 0:
		_on_animation_changed(0) 
		timeline.stop()

	_setup_animation_table()

# Inside PoseHUD.gd

@onready var anim_table: Tree = %AnimTable

func _setup_animation_table() -> void:
	if not timeline or not timeline.anim_player: return
	
	anim_table.columns = 4
	anim_table.hide_root = true
	
	# Structure layout columns
	anim_table.set_column_expand(0, true) # Animation title stretches
	#anim_table.set_column_custom_minimum_width(1, 60) # Speed
	#anim_table.set_column_custom_minimum_width(2, 60) # Steps
	#anim_table.set_column_custom_minimum_width(3, 50) # Loop Check
	
	# Set Headers
	anim_table.create_item()
	anim_table.set_column_title(0, "Animation")
	anim_table.set_column_title(1, "Speed")
	anim_table.set_column_title(2, "Steps")
	anim_table.set_column_title(3, "Loop")
	anim_table.column_titles_visible = true
	
	anim_table.item_selected.connect(_on_anim_row_selected)
	anim_table.item_edited.connect(_on_anim_cell_edited)
	
	_populate_anim_table()

func _populate_anim_table() -> void:
	anim_table.clear()
	var root = anim_table.create_item()
	
	var anim_list = timeline.get_animations()
	var active_anim_name = _get_current_anim()
	
	for anim_name in anim_list:
		var anim = timeline.anim_player.get_animation(anim_name)
		var row = anim_table.create_item(root)
		row.set_metadata(0, anim_name) # Track the string key name directly
		
		# Col 0: Name string entry
		row.set_text(0, anim_name)
		row.set_selectable(0, true)
		
		# Col 1: Playback speed scale value
		# Note: pulling default speed scale or hardcoded fallback value 1.0
		row.set_text(1, "1.0") 
		row.set_editable(1, true)
		
		# Col 2: Duration converted dynamically to total steps
		var total_steps = _time_to_steps(anim.length)
		row.set_text(2, str(total_steps))
		row.set_editable(2, true)
		
		# Col 3: Loop State check box flag configuration
		var is_looping = anim.loop_mode != Animation.LOOP_NONE
		row.set_cell_mode(3, TreeItem.CELL_MODE_CHECK)
		row.set_checked(3, is_looping)
		row.set_editable(3, true)
		
		# Auto-select the currently active animation row visually
		if anim_name == active_anim_name:
			row.select(0)

## Converts an animation length in seconds to total steps
func _time_to_steps(duration_seconds: float) -> int:
	if not timeline or timeline.step_duration <= 0: return 0
	return int(round(duration_seconds / timeline.step_duration))

## Converts a step count back to seconds
func _steps_to_time(steps: int) -> float:
	if not timeline: return 0.0
	return steps * timeline.step_duration

# --- CONTROLLER INTEGRATION ---
@onready var part_table: Tree = %PartTable

func _setup_part_table(markers: Array[PoseMarker]) -> void:
	part_table.columns = 5
	part_table.hide_root = true
	
	part_table.set_column_custom_minimum_width(0, 100)
	part_table.set_column_expand(0, true) # Animation title stretches

	# Create table header labels
	var root = part_table.create_item()
	part_table.set_column_title(0, "")
	part_table.set_column_title(1, "✧") #controlled
	part_table.set_column_title(2, "⬩➤") #follow parent rotation
	part_table.set_column_title(3, "ꗃx") #lock x
	part_table.set_column_title(4, "ꗃy") #lock y
	part_table.column_titles_visible = true
	
	# Wire selection and column checkbox modification clicks
	part_table.item_selected.connect(_on_table_part_selected)
	part_table.item_edited.connect(_on_table_cell_edited)
	
	# Populate rows dynamically out of the controller's engine array
	for marker in markers:
		var row = part_table.create_item(root)
		row.set_metadata(0, marker) # Keep a direct reference to the object
		
		# Col 0: Title Text
		row.set_text(0, marker.name)
		row.set_selectable(0, true)
		
		# Cols 1-5: Checkboxes
		_create_tree_checkbox(row, 1, marker.is_controlled)
		_create_tree_checkbox(row, 2, marker.follow_parent_rotation)
		
		# (Note: Ensure your PoseMarker class exports these properties if needed)
		var lock_x = marker.get("lock_x") if "lock_x" in marker else false
		var lock_y = marker.get("lock_y") if "lock_y" in marker else false
		
		_create_tree_checkbox(row, 3, lock_x)
		_create_tree_checkbox(row, 4, lock_y)
		

func _create_tree_checkbox(item: TreeItem, column: int, checked: bool) -> void:
	item.set_cell_mode(column, TreeItem.CELL_MODE_CHECK)
	item.set_checked(column, checked)
	item.set_editable(column, true)

## Fires when you click the row title string to switch target tracks
func _on_anim_row_selected() -> void:
	var selected_item = anim_table.get_selected()
	if not selected_item: return
	
	var anim_name = selected_item.get_metadata(0) as String
	
	# Find index matching your dropdown or switch directly via code interface
	if anim_dropdown:
		for i in range(anim_dropdown.item_count):
			if anim_dropdown.get_item_text(i) == anim_name:
				anim_dropdown.select(i)
				_on_animation_changed(i) # Trigger the hot-swap system we built yesterday
				break

## Fires when values or checkbox configurations shift inside your rows
func _on_anim_cell_edited() -> void:
	var edited_item = anim_table.get_edited()
	var col = anim_table.get_edited_column()
	if not edited_item: return
	
	var anim_name = edited_item.get_metadata(0) as String
	var anim = timeline.anim_player.get_animation(anim_name)
	
	match col:
		1:
			# Update playback speed context safely
			var speed_val = float(edited_item.get_text(col))
			if timeline.anim_player:
				timeline.anim_player.speed_scale = speed_val
		2:
			# Update overall duration length mapping using raw steps conversion
			var target_steps = int(edited_item.get_text(col))
			var next_time = _steps_to_time(target_steps)
			
			timeline.set_length(anim_name, next_time)
			
			# If it's the current running profile, rebuild the layout dots matrix instantly
			if anim_name == _get_current_anim():
				duration_box.set_value_no_signal(next_time)
				_build_step_grid(next_time)
				_update_grid_visuals()
		3:
			# Toggle loop behaviors cleanly between built-in engine parameters
			var should_loop = edited_item.is_checked(col)
			anim.loop_mode = Animation.LOOP_LINEAR if should_loop else Animation.LOOP_NONE

## Fires whenever you click a row text title
func _on_table_part_selected() -> void:
	var selected_item = part_table.get_selected()
	if selected_item:
		var target_marker = selected_item.get_metadata(0) as PoseMarker
		if pose_controller and target_marker:
			pose_controller.set_active_marker(target_marker)

## Fires whenever any checkbox toggles or offset numbers are updated in the table row
func _on_table_cell_edited() -> void:
	var edited_item = part_table.get_edited()
	var col = part_table.get_edited_column()
	if not edited_item: return
	
	var marker = edited_item.get_metadata(0) as PoseMarker
	if not marker: return
	
	match col:
		1: 
			marker.is_controlled = edited_item.is_checked(col)
			if marker.is_controlled: marker.take_control()
			else: marker.release_control()
		2: marker.follow_parent_rotation = edited_item.is_checked(col)
		3: if "lock_x" in marker: marker.set("lock_x", edited_item.is_checked(col))
		4: if "lock_y" in marker: marker.set("lock_y", edited_item.is_checked(col))

func _on_swap_sibling_pressed():
	if not pose_controller or not pose_controller.active_marker: return
	pose_controller.swap_with_sibling(pose_controller.active_marker)

func _on_speed_box_changed(val: float):
	if timeline.anim_player:
		timeline.anim_player.speed_scale = val
	var anim = _get_current_anim()
	if anim != "" and timeline:
		timeline.key_speed_scale(anim, val)
		_update_grid_visuals()

func _on_active_marker_changed(marker: PoseMarker) -> void:
	if timeline.anim_player and timeline.anim_player.is_playing():
		timeline.stop()

	if not part_table: return
	# Loop and match row objects to highlight the correct row inside the table list layout
	var current_item = part_table.get_root().get_first_child()
	while current_item:
		if current_item.get_metadata(0) == marker:
			current_item.select(0) # Visually highlights the cell row row tracking match target node
			break
		current_item = current_item.get_next()
		
	_update_grid_visuals()

func _update_bone_info_checkboxes(marker: PoseMarker):
	if marker:
		controlled_check.set_pressed_no_signal(marker.is_controlled)
		follow_rotation_check.set_pressed_no_signal(marker.follow_parent_rotation)
		freeze_check.set_pressed_no_signal(marker.slave.freeze if marker.slave else false)
	else:
		controlled_check.set_pressed_no_signal(false)
		follow_rotation_check.set_pressed_no_signal(false)
		freeze_check.set_pressed_no_signal(false)

func _process(_delta: float) -> void:
	if not timeline or not timeline.anim_player: return
	
	var active_marker = pose_controller.active_marker if pose_controller else null
	var is_posing = posing_check.button_pressed

	# Keep UI in sync with playing animation
	if timeline.anim_player.is_playing():
		var playing_anim = timeline.anim_player.current_animation
		if not is_posing and playing_anim != "":
			for i in range(anim_dropdown.item_count):
				if anim_dropdown.get_item_text(i) == playing_anim:
					if anim_dropdown.selected != i:
						anim_dropdown.select(i)
						var current_anim_len = timeline.anim_player.get_animation(playing_anim).length
						duration_box.set_value_no_signal(current_anim_len)
						_build_step_grid(current_anim_len)
					break
		
		# Sync step sequencer visually
		var playing_step = timeline.get_current_playback_step()
		var max_steps = max(0, step_grid.get_child_count() - 1)
		playing_step = clampi(playing_step, 0, max_steps)
		
		if timeline.current_step != playing_step:
			timeline.current_step = playing_step
			_update_grid_visuals()
			if not is_posing:
				_update_bone_info_checkboxes(active_marker)

	# Read Realtime Physics Data for HUD
	if active_marker and active_marker.slave:
		var pos = active_marker.global_position
		pos_label.text = "    ⚲    Position: (%d, %d)" % [round(pos.x), round(pos.y)]
		rot_label.text = "    ↻    Rotation: %0.1f°" % rad_to_deg(active_marker.global_rotation)

# --- UI TOGGLES (Passes commands to the Controller) ---

func _on_controlled_toggled(toggled_on: bool) -> void:
	if pose_controller:
		pose_controller.toggle_controlled(toggled_on)
		_update_bone_info_checkboxes(pose_controller.active_marker)
		if record_check.button_pressed: _on_key_controlled_pressed()

func _on_rotation_toggled(toggled_on: bool) -> void:
	if pose_controller:
		pose_controller.toggle_follow_rotation(toggled_on)
		if record_check.button_pressed: _on_key_follow_rotation_pressed()

func _on_freeze_toggled(toggled_on: bool) -> void:
	if pose_controller:
		pose_controller.toggle_freeze(toggled_on)
		if record_check.button_pressed: _on_key_freeze_pressed()

func _on_pose_toggled(is_posing: bool) -> void:
	if pose_controller and pose_controller.player:
		pose_controller.player.is_posing = is_posing
		
	timeline.stop()
	
	if not is_posing:
		record_check.button_pressed = false
		if playback_controls_container: playback_controls_container.visible = false
	else:
		if playback_controls_container: playback_controls_container.visible = true

# --- KEYING ACTIONS (Passes commands to the TimelineManager) ---

func _get_current_anim() -> String:
	return anim_dropdown.get_item_text(anim_dropdown.selected) if anim_dropdown.item_count > 0 else ""

func _on_key_controlled_pressed():
	var marker = pose_controller.active_marker if pose_controller else null
	if marker:
		var anim = _get_current_anim()
		timeline.key_property(anim, marker, ":is_controlled", controlled_check.button_pressed)
		timeline.key_property(anim, marker.slave, ":freeze", marker.slave.freeze)
		_update_grid_visuals()

func _on_key_follow_rotation_pressed():
	var marker = pose_controller.active_marker if pose_controller else null
	if marker:
		timeline.key_property(_get_current_anim(), marker, ":follow_parent_rotation", follow_rotation_check.button_pressed)
		_update_grid_visuals()

func _on_key_position_pressed():
	var marker = pose_controller.active_marker if pose_controller else null
	if marker:
		timeline.key_property(_get_current_anim(), marker, ":position", marker.position)
		_update_grid_visuals()

func _on_key_rotation_pressed():
	var marker = pose_controller.active_marker if pose_controller else null
	if marker:
		timeline.key_property(_get_current_anim(), marker, ":rotation", marker.rotation)
		_update_grid_visuals()

func _on_key_freeze_pressed():
	var marker = pose_controller.active_marker if pose_controller else null
	if marker and marker.slave:
		timeline.key_property(_get_current_anim(), marker.slave, ":freeze", freeze_check.button_pressed)
		_update_grid_visuals()

func _on_key_all_pressed():
	if not pose_controller: return
	var anim = _get_current_anim()
	
	for m in pose_controller.all_markers:
		# 🆕 FILTER: If this marker is NOT controlled, skip keying its transforms entirely!
		#if not m.is_controlled:
			# Optional: Still key its control/freeze state flags so the animation player 
			# knows exactly when it hands control back over to physics
			#timeline.key_property(anim, m, ":is_controlled", m.is_controlled)
			#if m.slave:
			#	timeline.key_property(anim, m.slave, ":freeze", m.slave.freeze)
			#continue
			
		# Active, manually positioned limbs get full smart keying checks
		#timeline.key_property(anim, m, ":is_controlled", m.is_controlled)
		#timeline.key_property(anim, m, ":follow_parent_rotation", m.follow_parent_rotation)
		timeline.key_property(anim, m, ":position", m.position)
		if not m.follow_parent_rotation:
			timeline.key_property(anim, m, ":rotation", m.rotation)
		#if m.slave:
		#	timeline.key_property(anim, m.slave, ":freeze", m.slave.freeze)
			
	_update_grid_visuals()
# Called when the physical marker is dragged in the 2D view and "saved"
func _on_marker_save_requested(marker: PoseMarker) -> void:
	if not record_check.button_pressed: return
	var anim = _get_current_anim()
	timeline.key_property(anim, marker, ":rotation", marker.rotation)
	timeline.key_property(anim, marker, ":position", marker.position)
	_update_grid_visuals()

# --- REVERT HANDLERS ---

func _on_reset_position_pressed():
	var marker = pose_controller.active_marker if pose_controller else null
	if marker:
		timeline.remove_keyframe(_get_current_anim(), marker, ":position")
		if marker.has_method("revert_to_original"): marker.revert_to_original()
		_update_grid_visuals()

func _on_reset_rotation_pressed():
	var marker = pose_controller.active_marker if pose_controller else null
	if marker:
		timeline.remove_keyframe(_get_current_anim(), marker, ":rotation")
		if marker.has_method("revert_to_original"): marker.revert_to_original()
		_update_grid_visuals()

# --- STEP GRID & ANIMATION TIMELINE ---

func _populate_animations() -> void:
	anim_dropdown.clear()
	for anim_name in timeline.get_animations():
		anim_dropdown.add_item(anim_name)

func _on_duration_changed(new_duration: float) -> void:
	timeline.set_length(_get_current_anim(), new_duration)
	_build_step_grid(new_duration)
	_update_grid_visuals()

func _build_step_grid(duration: float) -> void:
	for child in step_grid.get_children():
		child.free()
		
	var num_steps = int(round(duration / timeline.step_duration)) + 1
	if num_steps < 1: num_steps = 1
	
	for i in range(num_steps):
		var step_rect = ColorRect.new()
		step_rect.custom_minimum_size = Vector2(28, 28) 
		var is_dark_group = (i / 4) % 2 == 0
		var base_color = Color(0.2, 0.2, 0.2) if is_dark_group else Color(0.35, 0.35, 0.35)
		
		step_rect.color = base_color
		step_rect.set_meta("base_color", base_color)
		
		var dot = ColorRect.new() 
		dot.custom_minimum_size = Vector2(16, 16)
		dot.set_anchors_preset(Control.PRESET_CENTER)
		dot.grow_horizontal = Control.GROW_DIRECTION_BOTH
		dot.grow_vertical = Control.GROW_DIRECTION_BOTH
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.visible = false
		step_rect.add_child(dot)
		
		step_rect.gui_input.connect(_on_step_clicked.bind(i))
		step_grid.add_child(step_rect)
		
	_update_grid_visuals()

func _on_step_clicked(event: InputEvent, step_index: int) -> void:
	if not posing_check.button_pressed: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# 🆕 Check if Ctrl (or Cmd on Mac) is being held down during the click
		var ctrl_pressed = event.is_command_or_control_pressed()
		
		if ctrl_pressed:
			# --- 👻 GHOST SELECTION MODE ---
			# Update the timeline selection index visually without moving the characters
			timeline.current_step = step_index
		else:
			# --- 🔄 STANDARD SHUTTLE MODE ---
			# Normal click behavior: select step and scrub the animation player
			timeline.seek_step(step_index)
			
		# Redraw selection bars and lookups instantly
		_update_grid_visuals()
		_update_bone_info_checkboxes(pose_controller.active_marker if pose_controller else null)
		
func _update_grid_visuals() -> void:
	var marker = pose_controller.active_marker if pose_controller else null
	var num_steps = step_grid.get_child_count()
	
	# Let the timeline calculate where the keys actually are!
	var visual_data = timeline.get_step_visual_data(_get_current_anim(), marker, num_steps)

	for i in range(num_steps):
		var step_rect: ColorRect = step_grid.get_child(i)
		var dot = step_rect.get_child(0) if step_rect.get_child_count() > 0 else null 
		
		# Set selection color
		if i == timeline.current_step:
			# 🆕 Calculate exactly where the physical character model is standing in time right now
			var physical_time = timeline.anim_player.current_animation_position if timeline.anim_player else 0.0
			var physical_step = int(round(physical_time / timeline.step_duration))
			
			if timeline.current_step == physical_step:
				step_rect.color = Color(0.3, 0.6, 1.0) # Standard Blue (Sync mode - character is here)
			else:
				step_rect.color = Color(0.6, 0.3, 0.8) # Ghost Purple (Ghost mode - character is elsewhere!)
		else:
			step_rect.color = step_rect.get_meta("base_color", Color(0.2, 0.2, 0.2))
				
		if not dot: continue
			
		# Render the dots based on timeline data
		var frame_data = visual_data[i]
		if frame_data["active"]:
			dot.visible = true
			dot.modulate = Color.RED
		elif frame_data["any"]:
			dot.visible = true
			dot.modulate = Color.WHITE
		else:
			dot.visible = false
			
	# 1. Fetch the raw seconds for the currently selected step
	var current_step_time: float = timeline.current_step * timeline.step_duration

	# 2. Break it down into whole seconds and remaining milliseconds/frames
	var whole_seconds: int = int(current_step_time)
	var milliseconds: int = int((current_step_time - whole_seconds) * 100)

	# 3. Format into a clean MM:SS.mm or SS.mm string block
	# %02d forces two digits with leading zeros (e.g., "02" instead of "2")
	var timecode_text: String = "%02d:%02d.%02d" % [
		int(whole_seconds / 60), # Minutes
		whole_seconds % 60,      # Seconds
		milliseconds             # Milliseconds / Step fraction
	]

	# 4. Assign it to your text block node (Change %TimecodeLabel to your actual node name)
	%TimecodeLabel.text = timecode_text

func _on_export_pressed() -> void:
	var current_anim = _get_current_anim()
	if current_anim != "" and timeline:
		timeline.save_animation_to_disk(current_anim)
		
func _on_play_pressed():
	if anim_dropdown.item_count > 0:
		playback_started.emit()
		timeline.play(_get_current_anim())

func _on_stop_pressed():
	timeline.stop()

func _on_rewind_pressed():
	timeline.seek_step(0)
	_update_grid_visuals()

func _on_animation_changed(_index: int) -> void:
	var current_anim = _get_current_anim()
	
	# 🆕 TRACK TRANSITION FIX: Check if the player is currently running
	var was_playing: bool = false
	if timeline.anim_player:
		was_playing = timeline.anim_player.is_playing()
		if was_playing:
			timeline.stop() # Interrupt the active playback cycle immediately
	
	if timeline.anim_player and anim_dropdown.item_count > 0:
		var anim = timeline.anim_player.get_animation(current_anim)
		duration_box.set_value_no_signal(anim.length)
		_build_step_grid(anim.length)
	
	# If it was playing, hot-swap and keep running the new animation instantly
	if was_playing:
		timeline.play(current_anim)
	else:
		# Standard behavior: rewind back to frame 0 if stopped
		_on_rewind_pressed()

func _on_reset_pressed() -> void:
	timeline.clear_animation(_get_current_anim())
	_update_grid_visuals()
