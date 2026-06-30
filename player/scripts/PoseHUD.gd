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
@onready var btn_play: Button = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/PlaybackControls/BtnPlay
@onready var btn_stop: Button = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/PlaybackControls/BtnStop
@onready var btn_rewind: Button = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/PlaybackControls/BtnRewind
@onready var btn_export: Button = %BtnExportAnimation

@onready var bone_dropdown: OptionButton = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/BoneDropdown
@onready var parent_label: Label = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/ParentLabel
@onready var pos_label: Label = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer/PosLabel
@onready var rot_label: Label = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer2/RotLabel

# Checkboxes & Keying Buttons
@onready var controlled_check: CheckBox = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer3/ControlledCheck
@onready var follow_rotation_check: CheckBox = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer4/FollowRotationCheck
@onready var freeze_check: CheckBox = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer5/FreezeCheck
@onready var record_check: CheckBox = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/PlaybackControls/RecordCheck
@onready var posing_check: CheckBox = $PanelContainer/MarginContainer/Mode/PosingCheck

@onready var btn_key_position: Button = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer/BtnKeyPos
@onready var btn_reset_position: Button = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer/BtnResetPos
@onready var btn_key_rotation: Button = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer2/BtnKeyRot
@onready var btn_reset_rotation: Button = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer2/BtnResetRot
@onready var btn_key_controlled: Button = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer3/BtnKeyControlled
@onready var btn_key_follow_rotation: Button = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer4/BtnKeyFollowRotation
@onready var btn_key_freeze: Button = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/VBoxContainer/HBoxContainer5/BtnKeyFreeze
@onready var btn_key_all: Button = $PanelContainer/MarginContainer/HBoxContainer/BoneInfo/HBoxContainer/BtnKeyAll
@onready var btn_reset: Button = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/PlaybackControls/BtnReset

@onready var playback_controls_container: Control = $PanelContainer/MarginContainer/HBoxContainer/AnimatorSection/PlaybackControls

func _ready() -> void:
	record_check.button_pressed = true
	posing_check.button_pressed = true
	
	if pose_controller:
		pose_controller.active_marker_changed.connect(_on_active_marker_changed)
		pose_controller.marker_list_ready.connect(_populate_bone_dropdown)
	
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
	btn_export.pressed.connect(_on_export_pressed)
	
	bone_dropdown.item_selected.connect(_on_bone_dropdown_selected)
	
	clear_hud()
	
	btn_play.pressed.connect(_on_play_pressed)
	btn_stop.pressed.connect(_on_stop_pressed)
	btn_rewind.pressed.connect(_on_rewind_pressed)
	btn_reset.pressed.connect(_on_reset_pressed)
	speed_box.value_changed.connect(func(val): if timeline.anim_player: timeline.anim_player.speed_scale = val)
	duration_box.value_changed.connect(_on_duration_changed)
	anim_dropdown.item_selected.connect(_on_animation_changed)
	
	_populate_animations()
	if timeline and anim_dropdown.item_count > 0:
		_on_animation_changed(0) 
		timeline.stop()

# --- CONTROLLER INTEGRATION ---

func _populate_bone_dropdown(markers: Array[PoseMarker]) -> void:
	bone_dropdown.clear()
	bone_dropdown.add_item("None")
	for i in range(markers.size()):
		var m = markers[i]
		if m.slave:
			bone_dropdown.add_item(m.slave.name)
			bone_dropdown.set_item_metadata(i + 1, m) 
			
		# Route the new save_requested signal from the refactored marker directly to our keying logic
		if not m.save_requested.is_connected(_on_marker_save_requested):
			m.save_requested.connect(_on_marker_save_requested)

func _on_bone_dropdown_selected(index: int) -> void:
	if not pose_controller: return
	if index == 0:
		pose_controller.set_active_marker(null)
	else:
		var marker = bone_dropdown.get_item_metadata(index)
		pose_controller.set_active_marker(marker)

func _on_active_marker_changed(marker: PoseMarker) -> void:
	if timeline.anim_player and timeline.anim_player.is_playing():
		timeline.stop()

	if marker:
		for i in range(bone_dropdown.item_count):
			if bone_dropdown.get_item_metadata(i) == marker:
				bone_dropdown.select(i)
				break
	else:
		clear_hud()
		
	_update_bone_info_checkboxes(marker)
	_update_grid_visuals()

func clear_hud() -> void:
	if(bone_dropdown.size):
		bone_dropdown.select(0)
	parent_label.text = "Parent: None"

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
		if not m.is_controlled:
			# Optional: Still key its control/freeze state flags so the animation player 
			# knows exactly when it hands control back over to physics
			timeline.key_property(anim, m, ":is_controlled", m.is_controlled)
			if m.slave:
				timeline.key_property(anim, m.slave, ":freeze", m.slave.freeze)
			continue
			
		# Active, manually positioned limbs get full smart keying checks
		timeline.key_property(anim, m, ":is_controlled", m.is_controlled)
		timeline.key_property(anim, m, ":follow_parent_rotation", m.follow_parent_rotation)
		timeline.key_property(anim, m, ":position", m.position)
		if not m.follow_parent_rotation:
			timeline.key_property(anim, m, ":rotation", m.rotation)
		if m.slave:
			timeline.key_property(anim, m.slave, ":freeze", m.slave.freeze)
			
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
		child.queue_free()
		
	var num_steps = int(round(duration / timeline.step_duration)) + 1
	if num_steps < 1: num_steps = 1
	
	for i in range(num_steps):
		var step_rect = ColorRect.new()
		step_rect.custom_minimum_size = Vector2(24, 24) 
		var is_dark_group = (i / 4) % 2 == 0
		var base_color = Color(0.2, 0.2, 0.2) if is_dark_group else Color(0.35, 0.35, 0.35)
		
		step_rect.color = base_color
		step_rect.set_meta("base_color", base_color)
		
		var dot = ColorRect.new() 
		dot.custom_minimum_size = Vector2(10, 10)
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
		timeline.seek_step(step_index)
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
			step_rect.color = Color(0.3, 0.6, 1.0)
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
	timeline.stop()
	_update_grid_visuals()

func _on_animation_changed(_index: int) -> void:
	if timeline.anim_player and anim_dropdown.item_count > 0:
		var anim = timeline.anim_player.get_animation(_get_current_anim())
		duration_box.set_value_no_signal(anim.length)
		_build_step_grid(anim.length)
	
	_update_grid_visuals()
	_on_rewind_pressed()

func _on_reset_pressed() -> void:
	timeline.clear_animation(_get_current_anim())
	_update_grid_visuals()
