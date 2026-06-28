extends CanvasLayer

signal playback_started

@export var anim_player: AnimationPlayer
@export var character: CharacterBody2D
@export var step_duration: float = 0.1 # Each step is 0.1 seconds apart

var active_marker: Node2D = null
var current_step: int = 0

# --- Animator UI References ---
@onready var anim_dropdown: OptionButton = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/Header/AnimDropdown
@onready var speed_box: SpinBox = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/Header/SpeedSpinBox
@onready var step_grid: HBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/StepGrid
@onready var btn_play: Button = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/PlaybackControls/BtnPlay
@onready var btn_stop: Button = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/PlaybackControls/BtnStop
@onready var btn_rewind: Button = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/PlaybackControls/BtnRewind

# --- UI References ---
@onready var title_label: Label = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/TitleLabel
@onready var parent_label: Label = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/ParentLabel
@onready var controlled_check: CheckBox = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/ControlledCheck
@onready var rotation_check: CheckBox = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/RotationCheck

@onready var slave_pos_label: Label = $PanelContainer/MarginContainer/HBoxContainer/TransformInfo/SlavePosLabel
@onready var slave_rot_label: Label = $PanelContainer/MarginContainer/HBoxContainer/TransformInfo/SlaveRotLabel
@onready var parent_pos_label: Label = $PanelContainer/MarginContainer/HBoxContainer/TransformInfo/ParentPosLabel
@onready var parent_rot_label: Label = $PanelContainer/MarginContainer/HBoxContainer/TransformInfo/ParentRotLabel

@onready var record_check: CheckBox = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/PlaybackControls/RecordCheck # Connect this in editor
@onready var freeze_check: CheckBox = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/FreezeCheck   # Connect this in editor
@onready var posing_check: CheckBox = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/PlaybackControls/PosingCheck   # Connect this in editor
@onready var btn_reset: Button = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/PlaybackControls/BtnReset # Connect this in editor/BtnReset

func _ready() -> void:
	controlled_check.toggled.connect(_on_controlled_toggled)
	rotation_check.toggled.connect(_on_rotation_toggled)
	freeze_check.toggled.connect(_on_freeze_toggled)
	posing_check.toggled.connect(_on_pose_toggled)
	clear_hud()
	
	# Setup Playback Buttons
	btn_play.pressed.connect(_on_play_pressed)
	btn_stop.pressed.connect(_on_stop_pressed)
	btn_rewind.pressed.connect(_on_rewind_pressed)
	btn_reset.pressed.connect(_on_reset_pressed)
	speed_box.value_changed.connect(_on_speed_changed)
	anim_dropdown.item_selected.connect(_on_animation_changed)	
	
	# Setup the 8 Step Grid Buttons
	for i in range(step_grid.get_child_count()):
		var step_rect = step_grid.get_child(i)
		step_rect.gui_input.connect(_on_step_clicked.bind(i))
	
	_populate_animations()
	_update_grid_visuals()

func set_active_marker(marker: Node2D) -> void:
	active_marker = marker
	if not active_marker:
		clear_hud()
		_update_grid_visuals()
		return
		
	title_label.text = "Selected Bone: " + (active_marker.slave.name if active_marker.slave else "None")
	parent_label.text = "Parent: " + (active_marker.slave_parent.name if active_marker.slave_parent else "None")
	
	controlled_check.set_pressed_no_signal(active_marker.is_controlled)
	rotation_check.set_pressed_no_signal(active_marker.follow_parent_rotation)
	freeze_check.set_pressed_no_signal(active_marker.slave.freeze)
	posing_check.set_pressed_no_signal(character.is_posing)
	
	_update_grid_visuals()

func clear_hud() -> void:
	title_label.text = "Selected Bone: None"
	parent_label.text = "Parent: None"
	slave_pos_label.text = "Slave Pos: (-, -)"
	slave_rot_label.text = "Slave Rot: -°"
	parent_pos_label.text = "Parent Pos: (-, -)"
	parent_rot_label.text = "Parent Rot: -°"
	controlled_check.set_pressed_no_signal(false)
	rotation_check.set_pressed_no_signal(false)

func _process(_delta: float) -> void:
	if active_marker and active_marker.slave:
		var s_pos = active_marker.slave.global_position
		slave_pos_label.text = "Slave Pos: (%d, %d)" % [round(s_pos.x), round(s_pos.y)]
		slave_rot_label.text = "Slave Rot: %0.1f°" % rad_to_deg(active_marker.slave.global_rotation)
		
		if active_marker.slave_parent:
			var p_pos = active_marker.slave_parent.global_position
			parent_pos_label.text = "Parent Pos: (%d, %d)" % [round(p_pos.x), round(p_pos.y)]
			parent_rot_label.text = "Parent Rot: %0.1f°" % rad_to_deg(active_marker.slave_parent.global_rotation)

	if anim_player and anim_player.is_playing():
		var current_time = anim_player.current_animation_position
		var playing_step = int(round(current_time / step_duration))
		playing_step = clampi(playing_step, 0, step_grid.get_child_count() - 1)
		
		if current_step != playing_step:
			current_step = playing_step
			_update_grid_visuals()

# --- UI Input Handlers ---
func _on_controlled_toggled(toggled_on: bool) -> void:
	if active_marker:
		if toggled_on:
			active_marker.take_control()
		else:
			active_marker.release_control()

func _on_rotation_toggled(toggled_on: bool) -> void:
	if active_marker:
		active_marker.follow_parent_rotation = toggled_on

# --- ANIMATOR FUNCTIONS ---

func _populate_animations() -> void:
	if not anim_player: return
	anim_dropdown.clear()
	for anim_name in anim_player.get_animation_list():
		anim_dropdown.add_item(anim_name)

func _on_step_clicked(event: InputEvent, step_index: int) -> void:
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		current_step = step_index
		var target_time = current_step * step_duration
		print(target_time)
		if anim_player:
			anim_player.seek(target_time, true)
			#anim_player.stop() 
					
		_update_grid_visuals()
		
func has_frames_at_step(step_index: int) -> bool:
	if not anim_player or anim_dropdown.item_count == 0: return false
	
	var anim_name = anim_dropdown.get_item_text(anim_dropdown.selected)
	if not anim_player.has_animation(anim_name): return false
	
	var animation = anim_player.get_animation(anim_name)
	var target_time = step_index * step_duration
	var time_tolerance = 0.01
	
	# Check all tracks in this animation
	for track_idx in animation.get_track_count():
		var key_idx = animation.track_find_key(track_idx, target_time, Animation.FIND_MODE_NEAREST)
		if key_idx != -1:
			if abs(animation.track_get_key_time(track_idx, key_idx) - target_time) <= time_tolerance:
				return true # Found at least one frame!
	return false
			
func _update_grid_visuals() -> void:
	var current_anim: Animation = null
	if anim_player and anim_dropdown.item_count > 0:
		var anim_name = anim_dropdown.get_item_text(anim_dropdown.selected)
		if anim_player.has_animation(anim_name):
			current_anim = anim_player.get_animation(anim_name)
			
	var active_path = ""
	if active_marker and active_marker.slave:
		active_path = str(anim_player.get_parent().get_path_to(active_marker))

	for i in range(step_grid.get_child_count()):
		var step_rect: ColorRect = step_grid.get_child(i)
		
		# ⚠️ CRITICAL: Ensure you added a child node to your ColorRects in the editor to act as the dot!
		var dot = step_rect.get_child(0) if step_rect.get_child_count() > 0 else null 
		
		if i == current_step:
			step_rect.color = Color(0.3, 0.6, 1.0)
		else:
			step_rect.color = Color(0.2, 0.2, 0.2)
			
		if not dot: continue
			
		var has_any_key = false
		var has_active_bone_key = false
		
		if current_anim:
			var target_time = i * step_duration
			var time_tolerance = 0.01
			
			for track_idx in current_anim.get_track_count():
				var key_idx = current_anim.track_find_key(track_idx, target_time, Animation.FIND_MODE_NEAREST)
				if key_idx != -1:
					var key_time = current_anim.track_get_key_time(track_idx, key_idx)
					if abs(key_time - target_time) <= time_tolerance:
						has_any_key = true
						var track_path = str(current_anim.track_get_path(track_idx))
						if active_path != "" and track_path.begins_with(active_path):
							has_active_bone_key = true
							break

		if has_active_bone_key:
			dot.visible = true
			dot.modulate = Color.RED
		elif has_any_key:
			dot.visible = true
			dot.modulate = Color.WHITE
		else:
			dot.visible = false

# --- AUTO SAVE LOGIC ---
func auto_save_pose(marker: Node2D) -> void:
	if not record_check.button_pressed: return
	if not anim_player or anim_dropdown.item_count == 0: return
	if not marker or not marker.slave: return
	
	# 1. Get the official Animation Root node defined in the AnimationPlayer
	# If root_node is not set, Godot defaults to the player's parent.
	var root_node = anim_player.get_node(anim_player.root_node)
	
	# 2. Get the path from that root to the target slave
	var relative_path = root_node.get_path_to(marker)
	
	# 3. Construct the path
	# If the root is PlayerBody and slave is Ragdoll/Leg, this yields "Ragdoll/Leg:rotation"
	var track_path = NodePath(str(relative_path) + ":rotation")
	
	print("DEBUG: Root is %s, Path is %s" % [root_node.name, track_path])
	
	var anim_name = anim_dropdown.get_item_text(anim_dropdown.selected)
	var animation: Animation = anim_player.get_animation(anim_name)
	
	_insert_key(animation, track_path, marker.rotation)
	_insert_key(animation, NodePath(str(relative_path) + ":position"), marker.position)
	#_insert_key(animation, NodePath(str(relative_path) + ":freeze"), marker.slave.freeze)
	
	_update_grid_visuals()
			
func _insert_key(anim: Animation, track_path: String, value: Variant) -> void:
	var track_idx = anim.find_track(track_path, Animation.TYPE_VALUE)
	if track_idx == -1:
		track_idx = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_idx, track_path)
		
		# Position and Rotation use Linear Interpolation (Continuous)
	if typeof(value) == TYPE_VECTOR2 or typeof(value) == TYPE_FLOAT:
		anim.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_LINEAR)
		# Note: Godot 4 handles the "continuous" aspect automatically based 
		# on the interpolation type.
	
	# Make sure timeline is long enough
	var total_required_time = step_grid.get_child_count() * step_duration
	if anim.length < total_required_time:
		anim.length = total_required_time
	
	anim.track_insert_key(track_idx, current_step * step_duration, value)

# --- PLAYBACK CONTROLS ---
func _on_play_pressed():
	if anim_player and anim_dropdown.item_count > 0:
		var anim_name = anim_dropdown.get_item_text(anim_dropdown.selected)
		playback_started.emit() # Tell manager to drop bones
		anim_player.play(anim_name)

func _on_stop_pressed():
	if anim_player:
		anim_player.stop()

func _on_pose_toggled(is_posing: bool):
	character.is_posing = is_posing

func _on_rewind_pressed():
	current_step = 0
	_update_grid_visuals()
	if anim_player:
		anim_player.seek(0, true)

func _on_speed_changed(new_speed: float):
	if anim_player:
		anim_player.speed_scale = new_speed

func _on_animation_changed(_index: int) -> void:
	# 🆕 The moment the animation changes, refresh the dots!
	_update_grid_visuals()
	
	# Optional: Seek to 0 so you are at the start of the new animation
	_on_rewind_pressed()

func _on_freeze_toggled(toggled_on: bool) -> void:
	print(toggled_on)
	if active_marker and active_marker.slave:
		active_marker.slave.freeze = toggled_on

func _on_reset_pressed() -> void:
	if anim_player and anim_dropdown.item_count > 0:
		var anim_name = anim_dropdown.get_item_text(anim_dropdown.selected)
		var animation = anim_player.get_animation(anim_name)
		# Clear all tracks
		while animation.get_track_count() > 0:
			animation.remove_track(0)
		_update_grid_visuals()
