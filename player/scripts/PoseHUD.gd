extends CanvasLayer

signal playback_started

@export var anim_player: AnimationPlayer
@export var character: Player
@export var ragdoll: RagdollManager
@export var step_duration: float = 0.1

var active_marker: Node2D = null
var current_step: int = 0

# --- Animator UI References ---
@onready var anim_dropdown: OptionButton = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/Header/AnimDropdown
@onready var speed_box: SpinBox = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/PlaybackControls/SpeedSpinBox
@onready var step_grid: HBoxContainer = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/StepGrid
@onready var btn_play: Button = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/PlaybackControls/BtnPlay
@onready var btn_stop: Button = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/PlaybackControls/BtnStop
@onready var btn_rewind: Button = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/PlaybackControls/BtnRewind

# --- UI References ---
@onready var bone_dropdown: OptionButton = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/BoneDropdown
@onready var parent_label: Label = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/ParentLabel

@onready var pos_label: Label = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer/PosLabel
@onready var btn_key_position: Button = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer/BtnKeyPos
@onready var btn_reset_position: Button = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer/BtnResetPos

@onready var rot_label: Label = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer2/RotLabel
@onready var btn_key_rotation: Button = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer2/BtnKeyRot
@onready var btn_reset_rotation: Button = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer2/BtnResetRot

@onready var controlled_check: CheckBox = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer3/ControlledCheck
@onready var btn_key_controlled: Button = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer3/BtnKeyControlled

@onready var follow_rotation_check: CheckBox = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer4/FollowRotationCheck
@onready var btn_key_follow_rotation: Button = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer4/BtnKeyFollowRotation

@onready var freeze_check: CheckBox = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer5/FreezeCheck
@onready var btn_key_freeze: Button = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer5/BtnKeyFreeze

@onready var slave_pos_label: Label = $PanelContainer/MarginContainer/HBoxContainer/TransformInfo/SlavePosLabel
@onready var slave_rot_label: Label = $PanelContainer/MarginContainer/HBoxContainer/TransformInfo/SlaveRotLabel
@onready var parent_pos_label: Label = $PanelContainer/MarginContainer/HBoxContainer/TransformInfo/ParentPosLabel
@onready var parent_rot_label: Label = $PanelContainer/MarginContainer/HBoxContainer/TransformInfo/ParentRotLabel

@onready var record_check: CheckBox = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/PlaybackControls/RecordCheck
@onready var posing_check: CheckBox = $PanelContainer/MarginContainer/Mode/PosingCheck
@onready var btn_reset: Button = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/PlaybackControls/BtnReset

@onready var btn_key_all: Button = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/HBoxContainer/BtnKeyAll

# Container reference to easily hide the panel holding playback controls
@onready var playback_controls_container: Control = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/PlaybackControls

var active_marker_position_revert
var active_marker_rotation_revert

func _ready() -> void:
	# Set default modes
	record_check.button_pressed = true
	character.is_posing = true
	posing_check.button_pressed = true
	
	controlled_check.toggled.connect(_on_controlled_toggled)
	follow_rotation_check.toggled.connect(_on_rotation_toggled)
	freeze_check.toggled.connect(_on_freeze_toggled)
	posing_check.toggled.connect(_on_pose_toggled)
	
	btn_key_controlled.pressed.connect(_on_key_controlled_pressed)
	btn_key_follow_rotation.pressed.connect(_on_key_follow_rotation_pressed)
	btn_key_freeze.pressed.connect(_on_key_freeze_pressed)
	btn_key_position.pressed.connect(_on_key_position_pressed)
	btn_key_rotation.pressed.connect(_on_key_rotation_pressed)
	btn_key_all.pressed.connect(_on_key_all_pressed)
	
	btn_reset_position.pressed.connect(_on_reset_position_pressed)
	btn_reset_rotation.pressed.connect(_on_reset_rotation_pressed)
	
	bone_dropdown.item_selected.connect(_on_bone_dropdown_selected)
	
	clear_hud()
	
	btn_play.pressed.connect(_on_play_pressed)
	btn_stop.pressed.connect(_on_stop_pressed)
	btn_rewind.pressed.connect(_on_rewind_pressed)
	btn_reset.pressed.connect(_on_reset_pressed)
	speed_box.value_changed.connect(_on_speed_changed)
	anim_dropdown.item_selected.connect(_on_animation_changed)
	
	for i in range(step_grid.get_child_count()):
		var step_rect = step_grid.get_child(i)
		step_rect.gui_input.connect(_on_step_clicked.bind(i))
	
	_populate_animations()
	_populate_bone_dropdown()
	_update_grid_visuals()
	anim_player.stop()

func _populate_bone_dropdown() -> void:
	bone_dropdown.clear()
	bone_dropdown.add_item("None")
	var markers = get_tree().get_nodes_in_group("anim_markers")
	for i in range(markers.size()):
		var m = markers[i]
		if m.slave:
			bone_dropdown.add_item(m.slave.name)
			bone_dropdown.set_item_metadata(i + 1, m) 

func _on_bone_dropdown_selected(index: int) -> void:
	if index == 0:
		set_active_marker(null)
	else:
		var marker = bone_dropdown.get_item_metadata(index)
		set_active_marker(marker)

func _on_marker_deactivated(_marker: Node2D):
	set_active_marker(null)

func set_active_marker(marker: Node2D) -> void:
	active_marker = marker
	if(anim_player.is_playing()):
		anim_player.stop()

	if active_marker:
		if not marker.request_save.is_connected(auto_save_pose):
			marker.request_save.connect(auto_save_pose)
		if not marker.request_deactivate.is_connected(_on_marker_deactivated):
			marker.request_deactivate.connect(_on_marker_deactivated)
			
		for i in range(bone_dropdown.item_count):
			if bone_dropdown.get_item_metadata(i) == marker:
				bone_dropdown.select(i)
				break
	else:
		clear_hud()
		return
		
	parent_label.text = "Parent: " + (active_marker.slave_parent.name if active_marker.slave_parent else "None")
	_update_bone_info_checkboxes()
	_update_grid_visuals()

func clear_hud() -> void:
	bone_dropdown.select(0)
	#parent_label.text = "Parent: None"
	#slave_pos_label.text = "Slave Pos: (-, -)"
	#slave_rot_label.text = "Slave Rot: -°"
	#parent_pos_label.text = "Parent Pos: (-, -)"
	#parent_rot_label.text = "Parent Rot: -°"
	_update_bone_info_checkboxes()

func _update_bone_info_checkboxes():
	if active_marker:
		controlled_check.set_pressed_no_signal(active_marker.is_controlled)
		follow_rotation_check.set_pressed_no_signal(active_marker.follow_parent_rotation)
		if active_marker.slave:
			freeze_check.set_pressed_no_signal(active_marker.slave.freeze)
		else:
			freeze_check.set_pressed_no_signal(false)
	else:
		controlled_check.set_pressed_no_signal(false)
		follow_rotation_check.set_pressed_no_signal(false)
		freeze_check.set_pressed_no_signal(false)

func _process(_delta: float) -> void:
	# 🆕 FEATURE: Track active animation player status when NOT in pose mode
	if anim_player and not character.is_posing and anim_player.is_playing():
		var playing_anim = anim_player.current_animation
		if playing_anim != "":
			for i in range(anim_dropdown.item_count):
				if anim_dropdown.get_item_text(i) == playing_anim:
					if anim_dropdown.selected != i:
						anim_dropdown.select(i)
						# Refresh track markers for the new animation
						_update_grid_visuals()
					break
		
		# Keep step grid sequencer position updated smoothly 
		var current_time = anim_player.current_animation_position
		if step_grid.get_child_count() > 0:
			var playing_step = int(round(current_time / step_duration))
			playing_step = clampi(playing_step, 0, step_grid.get_child_count() - 1)
			
			if current_step != playing_step:
				current_step = playing_step
				_update_grid_visuals()
				_update_bone_info_checkboxes()

	# Marker updates
	if active_marker and active_marker.slave:
		var pos = active_marker.global_position
		pos_label.text = "    ⚲    Position: (%d, %d)" % [round(pos.x), round(pos.y)]
		rot_label.text = "    ↻    Rotation: %0.1f°" % rad_to_deg(active_marker.global_rotation)

	# Regular execution for step sequencer parsing when animating via the editor tools
	if anim_player and character.is_posing and anim_player.is_playing():
		var current_time = anim_player.current_animation_position
		if step_grid.get_child_count() > 0:
			var playing_step = int(round(current_time / step_duration))
			playing_step = clampi(playing_step, 0, step_grid.get_child_count() - 1)
			if current_step != playing_step:
				current_step = playing_step
				_update_grid_visuals()

# --- UI Input Handlers ---
func _on_controlled_toggled(toggled_on: bool) -> void:
	if active_marker:
		if toggled_on: active_marker.take_control()
		else: active_marker.release_control()
		_update_bone_info_checkboxes()
		if record_check.button_pressed:
			var track_path = str(anim_player.get_node(anim_player.root_node).get_path_to(active_marker)) + ":is_controlled"
			_manual_key_insert(track_path, active_marker.is_controlled)
			track_path = str(anim_player.get_node(anim_player.root_node).get_path_to(active_marker.slave)) + ":freeze"
			_manual_key_insert(track_path, active_marker.slave.freeze)

func _on_rotation_toggled(toggled_on: bool) -> void:
	if active_marker:
		active_marker.follow_parent_rotation = toggled_on
		if record_check.button_pressed:
			var track_path = str(anim_player.get_node(anim_player.root_node).get_path_to(active_marker)) + ":follow_parent_rotation"
			_manual_key_insert(track_path, active_marker.follow_parent_rotation)

func _on_freeze_toggled(toggled_on: bool) -> void:
	if active_marker and active_marker.slave:
		active_marker.slave.freeze = toggled_on
		if record_check.button_pressed:
			var track_path = str(anim_player.get_node(anim_player.root_node).get_path_to(active_marker.slave)) + ":freeze"
			_manual_key_insert(track_path, active_marker.slave.freeze)

func _on_pose_toggled(is_posing: bool) -> void:
	character.is_posing = is_posing
	anim_player.stop()
	
	# 🆕 FEATURE: Handle layout state visibility variations based on Posing state
	if not is_posing:
		record_check.button_pressed = false
		if playback_controls_container:
			playback_controls_container.visible = false
	else:
		if playback_controls_container:
			playback_controls_container.visible = true

# --- MANUAL KEYING ---
func _on_key_controlled_pressed():
	if active_marker:
		var track_path = str(anim_player.get_node(anim_player.root_node).get_path_to(active_marker)) + ":is_controlled"
		_manual_key_insert(track_path, controlled_check.button_pressed)
		track_path = str(anim_player.get_node(anim_player.root_node).get_path_to(active_marker.slave)) + ":freeze"
		_manual_key_insert(track_path, active_marker.slave.freeze)
		
func _on_key_all_pressed():
	var markers = get_tree().get_nodes_in_group("anim_markers")
	var root_node = anim_player.get_node(anim_player.root_node)
	
	for i in range(markers.size()):
		var m = markers[i]
		var relative_path = root_node.get_path_to(m)
		var slave_path = root_node.get_path_to(m.slave) if m.slave else ""
		
		_manual_key_insert(str(relative_path) + ":is_controlled", m.is_controlled)
		_manual_key_insert(str(relative_path) + ":follow_parent_rotation", m.follow_parent_rotation)
		_manual_key_insert(str(relative_path) + ":position", m.position)
		_manual_key_insert(str(relative_path) + ":rotation", m.rotation)
		
		if m.slave:
			_manual_key_insert(str(slave_path) + ":freeze", m.slave.freeze)

func _on_key_follow_rotation_pressed():
	if active_marker:
		var track_path = str(anim_player.get_node(anim_player.root_node).get_path_to(active_marker)) + ":follow_parent_rotation"
		_manual_key_insert(track_path, follow_rotation_check.button_pressed)

func _on_key_position_pressed():
	if active_marker:
		var track_path = str(anim_player.get_node(anim_player.root_node).get_path_to(active_marker)) + ":position"
		_manual_key_insert(track_path, active_marker.position)

func _on_key_rotation_pressed():
	if active_marker:
		var track_path = str(anim_player.get_node(anim_player.root_node).get_path_to(active_marker)) + ":rotation"
		_manual_key_insert(track_path, active_marker.rotation)

func _on_key_freeze_pressed():
	if active_marker and active_marker.slave:
		var track_path = str(anim_player.get_node(anim_player.root_node).get_path_to(active_marker.slave)) + ":freeze"
		_manual_key_insert(track_path, freeze_check.button_pressed)

func _manual_key_insert(track_path: String, value: Variant):
	if not anim_player or anim_dropdown.item_count == 0: return
	var anim_name = anim_dropdown.get_item_text(anim_dropdown.selected)
	var animation: Animation = anim_player.get_animation(anim_name)
	_insert_key(animation, track_path, value)
	_update_grid_visuals()

# --- RESET HANDLERS ---
func _on_reset_position_pressed():
	_remove_keyframe(":position")
	if active_marker:
		if "original_position" in active_marker:
			active_marker.global_position = active_marker.original_position
		elif active_marker_position_revert != null:
			active_marker.global_position = active_marker_position_revert

func _on_reset_rotation_pressed():
	_remove_keyframe(":rotation")
	if active_marker:
		if "original_rotation" in active_marker:
			active_marker.global_rotation = active_marker.original_rotation
		elif active_marker_rotation_revert != null:
			active_marker.global_rotation = active_marker_rotation_revert

func _remove_keyframe(property_suffix: String):
	if not anim_player or anim_dropdown.item_count == 0 or not active_marker: return
	var anim_name = anim_dropdown.get_item_text(anim_dropdown.selected)
	var animation: Animation = anim_player.get_animation(anim_name)
	
	var root_node = anim_player.get_node(anim_player.root_node)
	var relative_path = root_node.get_path_to(active_marker)
	var track_path = str(relative_path) + property_suffix
	
	var track_idx = animation.find_track(track_path, Animation.TYPE_VALUE)
	if track_idx != -1:
		var target_time = current_step * step_duration
		var key_idx = animation.track_find_key(track_idx, target_time, Animation.FIND_MODE_NEAREST)
		
		if key_idx != -1:
			var key_time = animation.track_get_key_time(track_idx, key_idx)
			if abs(key_time - target_time) <= 0.01:
				animation.track_remove_key(track_idx, key_idx)
				
	_update_grid_visuals()

# --- ANIMATOR FUNCTIONS ---
func _populate_animations() -> void:
	if not anim_player: return
	anim_dropdown.clear()
	for anim_name in anim_player.get_animation_list():
		anim_dropdown.add_item(anim_name)

func _on_step_clicked(event: InputEvent, step_index: int) -> void:
	# Only allow manual step alteration if in configuration mode
	if not character.is_posing: return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		current_step = step_index
		var target_time = current_step * step_duration
		if anim_player:
			anim_player.seek(target_time, true)
		_update_grid_visuals()
		_update_bone_info_checkboxes()
			
func _update_grid_visuals() -> void:
	var current_anim: Animation = null
	if anim_player and anim_dropdown.item_count > 0:
		var anim_name = anim_dropdown.get_item_text(anim_dropdown.selected)
		if anim_player.has_animation(anim_name):
			current_anim = anim_player.get_animation(anim_name)
			
	var active_path = ""
	if active_marker and active_marker.slave:
		var root_node = anim_player.get_node(anim_player.root_node)
		active_path = str(root_node.get_path_to(active_marker))

	for i in range(step_grid.get_child_count()):
		var step_rect: ColorRect = step_grid.get_child(i)
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

func auto_save_pose(marker: Node2D) -> void:
	if not record_check.button_pressed: return
	if not anim_player or anim_dropdown.item_count == 0: return
	if not marker or not marker.slave: return
	
	var root_node = anim_player.get_node(anim_player.root_node)
	var relative_path = root_node.get_path_to(marker)
	
	var anim_name = anim_dropdown.get_item_text(anim_dropdown.selected)
	var animation: Animation = anim_player.get_animation(anim_name)
	
	_insert_key(animation, NodePath(str(relative_path) + ":rotation"), marker.rotation)
	_insert_key(animation, NodePath(str(relative_path) + ":position"), marker.position)
	
	_update_grid_visuals()
			
func _insert_key(anim: Animation, track_path: String, value: Variant) -> void:
	var track_idx = anim.find_track(track_path, Animation.TYPE_VALUE)
	if track_idx == -1:
		track_idx = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_idx, track_path)
		
	if typeof(value) == TYPE_VECTOR2 or typeof(value) == TYPE_FLOAT:
		anim.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_LINEAR)
	
	var total_required_time = step_grid.get_child_count() * step_duration
	if anim.length < total_required_time:
		anim.length = total_required_time
	
	anim.track_insert_key(track_idx, current_step * step_duration, value)

# --- PLAYBACK CONTROLS ---
func _on_play_pressed():
	if anim_player and anim_dropdown.item_count > 0:
		var anim_name = anim_dropdown.get_item_text(anim_dropdown.selected)
		playback_started.emit()
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

func _on_animation_changed(_index: int) -> void:
	_update_grid_visuals()
	_on_rewind_pressed()

func _on_reset_pressed() -> void:
	if anim_player and anim_dropdown.item_count > 0:
		var anim_name = anim_dropdown.get_item_text(anim_dropdown.selected)
		var animation = anim_player.get_animation(anim_name)
		animation.clear() 
		_update_grid_visuals()
