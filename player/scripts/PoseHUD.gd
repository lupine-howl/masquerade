extends CanvasLayer

@export var anim_player: AnimationPlayer
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

func _ready() -> void:
	controlled_check.toggled.connect(_on_controlled_toggled)
	rotation_check.toggled.connect(_on_rotation_toggled)
	
	clear_hud()
	
	# Setup Playback Buttons
	btn_play.pressed.connect(_on_play_pressed)
	btn_stop.pressed.connect(_on_stop_pressed)
	btn_rewind.pressed.connect(_on_rewind_pressed)
	speed_box.value_changed.connect(_on_speed_changed)
	
	# Setup the 8 Step Grid Buttons
	for i in range(step_grid.get_child_count()):
		var step_rect = step_grid.get_child(i)
		# Turn the ColorRect into a clickable button via its gui_input
		step_rect.gui_input.connect(_on_step_clicked.bind(i))
	
	_populate_animations()
	_update_grid_visuals()

func set_active_marker(marker: Node2D) -> void:
	active_marker = marker
	if not active_marker:
		clear_hud()
		return
		
	# Populate static bone info
	title_label.text = "Selected Bone: " + (active_marker.slave.name if active_marker.slave else "None")
	parent_label.text = "Parent: " + (active_marker.slave_parent.name if active_marker.slave_parent else "None")
	
	# 🆕 Set initial checkbox states based on the marker's own source of truth
	# (Ensure your marker script has 'var is_controlled: bool = false' declared!)
	controlled_check.set_pressed_no_signal(active_marker.is_controlled)
	rotation_check.set_pressed_no_signal(active_marker.follow_parent_rotation)

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

# --- UI Input Handlers ---
func _on_controlled_toggled(toggled_on: bool) -> void:
	if active_marker:
		# 🆕 Route the UI toggle directly to the marker's control methods
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
		
		# Move the animation player preview to this exact step
		if anim_player and anim_dropdown.item_count > 0:
			var anim_name = anim_dropdown.get_item_text(anim_dropdown.selected)
			var target_time = current_step * step_duration
			anim_player.play(anim_name)
			anim_player.seek(target_time, true)
			anim_player.stop() # Stay paused on the frame
			
		_update_grid_visuals()

func _update_grid_visuals() -> void:
	# Highlight the selected box
	for i in range(step_grid.get_child_count()):
		var step_rect = step_grid.get_child(i)
		if i == current_step:
			step_rect.color = Color(0.3, 0.6, 1.0) # Active Blue
		else:
			step_rect.color = Color(0.2, 0.2, 0.2) # Inactive Gray

# --- AUTO SAVE LOGIC ---

# 🆕 CALL THIS FROM YOUR MANAGER WHEN A MARKER IS DROPPED
func auto_save_pose(marker: Node2D) -> void:
	if not anim_player or anim_dropdown.item_count == 0: return
	if not marker or not marker.slave: return
	
	var anim_name = anim_dropdown.get_item_text(anim_dropdown.selected)
	var animation: Animation = anim_player.get_animation(anim_name)
	var time = current_step * step_duration
	
	# Determine the path to the rigid body relative to the AnimationPlayer
	# E.g., "Skeleton/LeftFoot"
	var slave_path = str(anim_player.get_parent().get_path_to(marker.slave))
	
	# Helper to inject keys
	_insert_key(animation, slave_path + ":global_position", marker.slave.global_position)
	_insert_key(animation, slave_path + ":global_rotation", marker.slave.global_rotation)
	_insert_key(animation, slave_path + ":freeze", marker.slave.freeze)
	
	print("Auto-Saved %s at Step %d" % [marker.slave.name, current_step])

func _insert_key(anim: Animation, track_path: String, value: Variant) -> void:
	# Find the track, or create it if it doesn't exist
	var track_idx = anim.find_track(track_path, Animation.TYPE_VALUE)
	if track_idx == -1:
		track_idx = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_idx, track_path)
	
	# Insert the new value at the current step time
	anim.track_insert_key(track_idx, current_step * step_duration, value)

# --- PLAYBACK CONTROLS ---
func _on_play_pressed():
	if anim_player and anim_dropdown.item_count > 0:
		var anim_name = anim_dropdown.get_item_text(anim_dropdown.selected)
		anim_player.play(anim_name)

func _on_stop_pressed():
	if anim_player:
		anim_player.stop()

func _on_rewind_pressed():
	current_step = 0
	_update_grid_visuals()
	if anim_player:
		anim_player.seek(0, true)

func _on_speed_changed(new_speed: float):
	if anim_player:
		anim_player.speed_scale = new_speed
