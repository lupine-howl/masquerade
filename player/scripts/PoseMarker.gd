class_name PoseMarker
extends Node2D

# --- GLOBAL BROADCAST SIGNALS ---
signal selected(marker: PoseMarker)
signal deselected(marker: PoseMarker)
signal drag_ended(marker: PoseMarker)
signal save_requested(marker: PoseMarker)
signal dragged_position(delta: Vector2)
signal dragged_rotation(delta_angle: float)

@export var slave: RigidBody2D
@export var slave_parent: RigidBody2D # Default fallback parent node
@export var sibling: PoseMarker
@export var pivot: Node2D
@export var invert_rotation_on_flip: bool

@export_category("Dimensions")
@export var inner_radius: float = 16.0   
@export var outer_radius: float = 24.0   

@export_category("Settings")
@export var is_dev_mode: bool = true
@export var drag_threshold: float = 3.0
@export var can_rotate: bool = false
@export var is_controlled: bool = true

# --- HIGH-FREQUENCY ANIMATION TARGETS (Driven by Canvas Mouse / HUD) ---
@export_category("Animation Targets")
@export var offset_x: float = 0.0
@export var offset_y: float = 0.0
@export var rotation_offset_deg: float = 0.0

@export var global_x: bool = false
@export var global_y: bool = false
@export var follow_parent_rotation: bool = true 

# --- DETAILED CONSTRAINT DEFINITIONS (Set up via Rigging Configuration) ---
@export_category("X-Axis Constraint")
@export var use_min_max_x: bool = false
@export var min_x: float = -100.0
@export var max_x: float = 100.0
@export var x_constraint_parent: RigidBody2D # Override parent for X-bounds math

@export_category("Y-Axis Constraint")
@export var use_min_max_y: bool = false
@export var min_y: float = -100.0
@export var max_y: float = 100.0
@export var y_constraint_parent: RigidBody2D # Override parent for Y-bounds math

@export_category("Radius Constraint")
@export var use_radius_limit: bool = false
@export var max_radius: float = 50.0
@export var radius_is_global: bool = false
@export var radius_constraint_parent: RigidBody2D # Override center parent (e.g., Pelvis)

@export_category("Rotation Constraint")
@export var use_rotation_limit: bool = false
@export var min_rotation_deg: float = -45.0
@export var max_rotation_deg: float = 45.0
@export var rotation_constraint_parent: RigidBody2D # Override rotational reference (e.g., Calf)

# Interaction States
var is_dragging_position: bool = false
var is_dragging_rotation: bool = false
var mouse_over: bool = false
var is_active: bool = false

# Internal Drag States
var _is_prepare_drag_position: bool = false
var _is_prepare_drag_rotation: bool = false
var _mouse_start_pos: Vector2 = Vector2.ZERO
var _drag_offset: Vector2 = Vector2.ZERO

# Unsaved Source-of-Truth States
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
	if is_controlled: take_control()

func set_active(active_state: bool) -> void:
	is_active = active_state
	if not is_active: _reset_marker_ui()

func _process(_delta: float) -> void:
	if not is_dev_mode: return
	var mouse_pos = get_global_mouse_position()
	
	# Keep visual component visibility straight
	inner_circle_uncontrolled.visible = not is_controlled
	rotation_indicator_uncontrolled.visible = not is_controlled and can_rotate
	inner_circle_controlled.visible = is_controlled
	rotation_indicator_controlled.visible = is_controlled and can_rotate
	inner_circle_selected.visible = is_active
	rotation_indicator_selected.visible = is_active and can_rotate
	outer_rotation_ring.visible = is_active and can_rotate and is_controlled
	
	# EVALUATE DRAG THRESHOLDS BEFORE MUTATING
	if _is_prepare_drag_position and not is_dragging_position:
		if mouse_pos.distance_to(_mouse_start_pos) > drag_threshold:
			_capture_original_state()
			is_dragging_position = true
			
	if _is_prepare_drag_rotation and not is_dragging_rotation:
		if mouse_pos.distance_to(_mouse_start_pos) > drag_threshold:
			_capture_original_state()
			is_dragging_rotation = true
	
	# Dragging updates (these modify the offset/targets, which _physics_process then clamps)
	if is_dragging_position:
		var target_pos = mouse_pos - _drag_offset
		var delta_pos = target_pos - global_position
		
		if delta_pos != Vector2.ZERO:
			# Update the targets so the physics process has the new raw data to clamp
			if global_x: offset_x = target_pos.x
			else: offset_x = target_pos.x - (slave_parent.global_position.x if slave_parent else 0.0)
				
			if global_y: offset_y = target_pos.y
			else: offset_y = target_pos.y - (slave_parent.global_position.y if slave_parent else 0.0)
				
			dragged_position.emit(delta_pos)
			
	elif is_dragging_rotation:
		var target_rot = global_position.angle_to_point(mouse_pos)
		var delta_rot = target_rot - global_rotation
		
		if delta_rot != 0.0:
			var rot_parent = rotation_constraint_parent if rotation_constraint_parent else slave_parent
			var base_rot = rot_parent.global_rotation if rot_parent else 0.0
			rotation_offset_deg = rad_to_deg(target_rot - base_rot)
			
			dragged_rotation.emit(delta_rot)

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
	if slave: slave.freeze = false

func _physics_process(_delta: float) -> void:
	if not slave: return
	
	# Determine fallback positions 
	var default_parent_pos = slave_parent.global_position if slave_parent else Vector2.ZERO
	var final_pos = global_position
	
	if is_controlled:
		# 1. SOLVE RESOLUTION SPACE (Local vs Global)
		if global_x:
			final_pos.x = offset_x
		else:
			final_pos.x = default_parent_pos.x + offset_x
			
		if global_y:
			final_pos.y = offset_y
		else:
			final_pos.y = default_parent_pos.y + offset_y

		# 2. EVALUATE TARGETED MULTI-PARENT POSITION CONSTRAINTS
		if use_min_max_x:
			var ref_x = x_constraint_parent.global_position.x if x_constraint_parent else (0.0 if global_x else default_parent_pos.x)
			final_pos.x = clamp(final_pos.x, ref_x + min_x, ref_x + max_x)
			
		if use_min_max_y:
			var ref_y = y_constraint_parent.global_position.y if y_constraint_parent else (0.0 if global_y else default_parent_pos.y)
			final_pos.y = clamp(final_pos.y, ref_y + min_y, ref_y + max_y)

		# 3. EVALUATE TARGETED DISTANCE CONSTRAINTS (RADIUS)
		if use_radius_limit:
			var center_node = radius_constraint_parent if radius_constraint_parent else slave_parent
			var origin_point = Vector2.ZERO if (radius_is_global or not center_node) else center_node.global_position
			
			if final_pos.distance_to(origin_point) > max_radius:
				final_pos = origin_point + (final_pos - origin_point).normalized() * max_radius

		global_position = final_pos
		slave.global_position = final_pos

		# 4. EVALUATE TARGETED ROTATIONAL CONSTRAINTS
		var rot_parent = rotation_constraint_parent if rotation_constraint_parent else slave_parent
		var target_rotation = global_rotation
		
		if follow_parent_rotation and rot_parent:
			target_rotation = rot_parent.global_rotation + deg_to_rad(rotation_offset_deg)
		else:
			target_rotation = deg_to_rad(rotation_offset_deg)
		
		if use_rotation_limit:
			var base_rot = rot_parent.global_rotation if rot_parent else 0.0
			var local_angle = wrapf(rad_to_deg(target_rotation - base_rot), -180, 180)
			local_angle = clamp(local_angle, min_rotation_deg, max_rotation_deg)
			target_rotation = base_rot + deg_to_rad(local_angle)
			
		var is_flipped = pivot and pivot.scale.x < 0
		if invert_rotation_on_flip and is_flipped: 
			target_rotation += deg_to_rad(180)

		slave.global_rotation = target_rotation
		global_rotation = slave.global_rotation

	else:
		# --- MODE B: PHYSICS PUSHING STATE BACK TO DEVELOPER MARKER ---
		# Keep the marker snapped to the physical ragdoll piece while it swings around
		global_position = slave.global_position
		global_rotation = slave.global_rotation

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

func revert_to_original() -> void:
	if not has_unsaved_changes: return 
	global_position = original_position
	global_rotation = original_rotation
	_reset_marker_ui()
