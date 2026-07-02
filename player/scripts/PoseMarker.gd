class_name PoseMarker
extends Node2D

# --- GLOBAL BROADCAST SIGNALS ---
signal selected(marker: PoseMarker)
signal deselected(marker: PoseMarker)
signal drag_ended(marker: PoseMarker)
signal save_requested(marker: PoseMarker)

# 🆕 Multi-Select Drag Delta Broadcasters
signal dragged_position(delta: Vector2)
signal dragged_rotation(delta_angle: float)

@export var slave: RigidBody2D
@export var slave_parent: RigidBody2D
@export var sibling: PoseMarker
@export var can_rotate: bool = false
@export var follow_parent_rotation: bool = false
@export var is_controlled: bool = true
@export var pivot: Node2D
@export var invert_rotation_on_flip: bool

@export_category("Dimensions")
@export var inner_radius: float = 16.0   
@export var outer_radius: float = 24.0   

@export_category("Settings")
@export var is_dev_mode: bool = true
@export var drag_threshold: float = 3.0

@export_category("Axis Locks")
@export var use_lock_x: bool = false
@export var lock_x_val: float = 0.0
@export var use_lock_y: bool = false
@export var lock_y_val: float = 0.0

# Interaction States
var is_dragging_position: bool = false
var is_dragging_rotation: bool = false
var mouse_over: bool = false
var is_active: bool = false

# Internal Drag-Correction Math States
var _is_prepare_drag_position: bool = false
var _is_prepare_drag_rotation: bool = false
var _mouse_start_pos: Vector2 = Vector2.ZERO
var _drag_offset: Vector2 = Vector2.ZERO

# Unsaved State Tracking (Source of Truth)
var original_position: Vector2
var original_rotation: float
var has_unsaved_changes: bool = false

@onready var area_2d: Area2D = $Area2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var outer_rotation_ring: Panel = $OuterRotationRing
@onready var inner_circle_controlled: Panel = $InnerMoveCircleControlled
@onready var inner_circle_uncontrolled: Panel = $InnerMoveCircleUncontrolled
@onready var inner_circle_selected: Panel = $InnerMoveCircleSelected
@onready var rotation_indicator_controlled: Panel = $InnerMoveCircleControlled/RotationIndicator
@onready var rotation_indicator_uncontrolled: Panel = $InnerMoveCircleUncontrolled/RotationIndicator
@onready var rotation_indicator_selected: Panel = $InnerMoveCircleSelected/RotationIndicator

func _ready() -> void:
	area_2d.mouse_entered.connect(func(): mouse_over = true)
	area_2d.mouse_exited.connect(func(): mouse_over = false)
	
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = outer_radius
	
	if slave:
		global_position = slave.global_position
		global_rotation = slave.global_rotation
				
	set_active(false)
	
	if is_controlled:
		take_control()

func set_active(active_state: bool) -> void:
	is_active = active_state
	if not is_active:
		_reset_marker_ui()

func _process(_delta: float) -> void:
	if not is_dev_mode: return
		
	var mouse_pos = get_global_mouse_position()
	
	# Update visual states
	inner_circle_uncontrolled.visible = not is_controlled
	rotation_indicator_uncontrolled.visible = not is_controlled and can_rotate
	inner_circle_controlled.visible = is_controlled
	rotation_indicator_controlled.visible = is_controlled and can_rotate
	inner_circle_selected.visible = is_active
	rotation_indicator_selected.visible = is_active and can_rotate
	outer_rotation_ring.visible = is_active and can_rotate and not follow_parent_rotation and is_controlled
	
	# EVALUATE DRAG THRESHOLDS BEFORE MUTATING
	if _is_prepare_drag_position and not is_dragging_position:
		if mouse_pos.distance_to(_mouse_start_pos) > drag_threshold:
			_capture_original_state()
			is_dragging_position = true
			
	if _is_prepare_drag_rotation and not is_dragging_rotation:
		if mouse_pos.distance_to(_mouse_start_pos) > drag_threshold:
			_capture_original_state()
			is_dragging_rotation = true
	
# 🆕 Translocation updates with Delta Broadcasting and Axis Locks
	if is_dragging_position:
		var target_pos = mouse_pos - _drag_offset
		
		# Clamp the target position if locks are active
		if use_lock_x: target_pos.x = lock_x_val
		if use_lock_y: target_pos.y = lock_y_val
		
		var delta_pos = target_pos - global_position
		if delta_pos != Vector2.ZERO:
			global_position = target_pos
			dragged_position.emit(delta_pos)
			
	elif is_dragging_rotation:
		var target_rot = global_position.angle_to_point(mouse_pos)
		var delta_rot = target_rot - global_rotation
		if delta_rot != 0.0:
			global_rotation = target_rot
			dragged_rotation.emit(delta_rot)
			
	# 🆕 Hard-enforce locks at the end of the frame (stops physics drifting)
	if use_lock_x: global_position.x = lock_x_val
	if use_lock_y: global_position.y = lock_y_val
	
func take_control():
	if slave:
		slave.freeze = true
		is_controlled = true
		slave.linear_velocity = Vector2.ZERO
		slave.angular_velocity = 0.0
		global_position = slave.global_position
		global_rotation = slave.global_rotation	

func release_control():
	is_controlled = false
	if slave:
		slave.freeze = false

func _physics_process(_delta: float) -> void:
	if not slave: return
	
	var is_flipped = pivot and pivot.scale.x < 0
	var target_rotation = global_rotation_degrees
	
	if slave_parent and follow_parent_rotation:
		target_rotation = slave_parent.global_rotation_degrees
	if invert_rotation_on_flip and is_flipped: 
		target_rotation += 180

	slave.global_rotation_degrees = target_rotation
	if follow_parent_rotation:
		global_rotation = slave.global_rotation
	
	if is_controlled:
		slave.global_position = global_position

func _input(event: InputEvent) -> void:
	if not is_dev_mode: return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		
		if event.pressed and mouse_over:
			var distance = global_position.distance_to(mouse_pos)
			
			if distance <= outer_radius:
				selected.emit(self)
			
			if distance <= inner_radius:
				_mouse_start_pos = mouse_pos
				
				# 🆕 Check if 'R' is held to swap to rotation mode safely
				if Input.is_key_pressed(KEY_R) and can_rotate and outer_rotation_ring.visible:
					_is_prepare_drag_rotation = true
				else:
					_drag_offset = mouse_pos - global_position 
					_is_prepare_drag_position = true
					
				get_viewport().set_input_as_handled()
				
			elif distance > inner_radius and distance <= outer_radius:
				if outer_rotation_ring.visible:
					_mouse_start_pos = mouse_pos
					_is_prepare_drag_rotation = true
					get_viewport().set_input_as_handled()
					
		elif not event.pressed:
			var was_dragging = is_dragging_position or is_dragging_rotation
			is_dragging_position = false
			is_dragging_rotation = false
			_is_prepare_drag_position = false
			_is_prepare_drag_rotation = false
			
			if was_dragging:
				_show_unsaved_state()
				drag_ended.emit(self)

# --- STATE MANAGEMENT ---

func _capture_original_state():
	if not has_unsaved_changes:
		original_position = global_position
		original_rotation = global_rotation
		has_unsaved_changes = true

func _show_unsaved_state():
	var unsaved_color = Color(1.0, 0.5, 0.0) 
	if inner_circle_selected: inner_circle_selected.modulate = unsaved_color
	if outer_rotation_ring: outer_rotation_ring.modulate = unsaved_color

func _reset_marker_ui():
	has_unsaved_changes = false
	if inner_circle_selected: inner_circle_selected.modulate = Color.WHITE
	if outer_rotation_ring: outer_rotation_ring.modulate = Color.WHITE

func _on_save_pressed():
	save_requested.emit(self) 
	_reset_marker_ui()

func _on_revert_pressed():
	revert_to_original()
	
func revert_to_original() -> void:
	if not has_unsaved_changes: return 
	
	global_position = original_position
	global_rotation = original_rotation
	
	_reset_marker_ui()
