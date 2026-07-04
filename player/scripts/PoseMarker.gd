class_name PoseMarker
extends Node2D

signal selected(marker: PoseMarker)
signal deselected(marker: PoseMarker)
signal drag_ended(marker: PoseMarker)
signal dragged_position(delta: Vector2)
signal dragged_rotation(delta_angle: float)

@export var slave: RigidBody2D ## RigidBody2D driven by this marker when controlled. The marker snaps to the slave when uncontrolled.
@export var sibling: PoseMarker ## Optional paired marker used by sibling-swap posing tools.
@export var pivot: Node2D ## Facing pivot (usually the sprite root). Used for flip detection and authored rotation under a mirrored hierarchy.
@export var invert_rotation_on_flip: bool ## When the facing pivot is flipped (scale.x < 0), apply flip_rotation_compensation_deg to the slave so limb rotation stays visually correct.
@export var flip_rotation_compensation_deg: float = 180.0 ## Extra rotation (degrees) added to the slave when invert_rotation_on_flip applies. Typically 180 for mirrored limbs.

@export_category("Dimensions")
@export var inner_radius: float = 16.0 ## Hit radius for selecting and dragging position (pixels, in marker local space before scale).
@export var outer_radius: float = 24.0 ## Hit radius for the rotation ring and outer selection area. Also sets the Area2D collision shape at runtime.

@export_category("Settings")
@export var is_dev_mode: bool = true ## When false, mouse input and on-screen gizmo visuals are disabled (for gameplay builds).
@export var drag_threshold: float = 3.0 ## Pixels the mouse must move before a click becomes a drag, avoiding accidental moves.
@export var can_rotate: bool = false ## Shows the rotation ring and allows R+drag or outer-ring drag to edit rotation in pose mode.
@export var is_controlled: bool = true ## When true, the marker drives the slave (slave is frozen). When false, the slave drives the marker (physics/ragdoll).
@export var constrain_rotation_when_uncontrolled: bool = false ## While uncontrolled, still solve look-at / follow / ground-lock / rotation-limit and write rotation to the slave instead of copying slave rotation.

@export_category("X-Axis Constraint")
@export var use_min_max_x: bool = false ## Clamp world X while the marker is controlled (and during drag before physics sync).
@export var min_x: float = -100.0 ## Minimum allowed X, relative to x_constraint_parent world X. Ignored when use_min_max_x is false.
@export var max_x: float = 100.0 ## Maximum allowed X, relative to x_constraint_parent world X. Ignored when use_min_max_x is false.
@export var x_constraint_parent: Node2D ## World X reference for min_x/max_x. Leave empty to use world origin (X = 0). Typically assign a torso or root body so limits move with the character.

@export_category("Y-Axis Constraint")
@export var use_min_max_y: bool = false ## Clamp world Y while the marker is controlled.
@export var min_y: float = -100.0 ## Minimum allowed Y, relative to y_constraint_parent world Y. Ignored when use_min_max_y is false.
@export var max_y: float = 100.0 ## Maximum allowed Y, relative to y_constraint_parent world Y (Godot Y+ is down). Applied after radius limit so this floor/ceiling always wins.
@export var y_constraint_parent: Node2D ## World Y reference for min_y/max_y. Leave empty to use world origin (Y = 0). Assign a node at ground level, or leave empty for a fixed world-Y floor/ceiling.

@export_category("Radius Constraint")
@export var use_radius_limit: bool = false ## Keep the marker within max_radius of the radius origin.
@export var max_radius: float = 50.0 ## Maximum distance from the radius origin (pixels in world space).
@export var radius_is_global: bool = false ## When true, the origin is always world (0, 0). When false, uses radius_constraint_parent global position, or (0, 0) if that is also empty.
@export var radius_constraint_parent: Node2D ## Center of the radius limit in world space. Leave empty (with radius_is_global false) to anchor at world origin. Often the parent limb or torso.
@export var radius_drag_partner: PoseMarker ## Optional second marker on the same radius. When this marker hits the limit while dragging, the partner is pushed to the opposite point on the circle (useful for paired hands/feet).

@export_category("Rotation Constraint")
@export var use_rotation_limit: bool = false ## Clamp solved rotation to a local angle range relative to rotation_constraint_parent (or follow target if parent is empty).
@export var min_rotation_deg: float = -45.0 ## Minimum local rotation in degrees, relative to the rotation base node.
@export var max_rotation_deg: float = 45.0 ## Maximum local rotation in degrees, relative to the rotation base node.
@export var rotation_constraint_parent: RigidBody2D ## Rotation base for min/max limits. Leave empty to use follow_rotation_target if set, otherwise world rotation 0° (global east).

@export_category("Follow Rotation")
@export var use_follow_rotation: bool = false ## Match this marker's rotation to follow_rotation_target plus follow_rotation_offset_deg.
@export var follow_rotation_target: Node2D ## Node whose global rotation is the base. Dragging with R adjusts the offset while keeping the aim direction relative to this target.
@export var follow_rotation_offset_deg: float = 0.0 ## Added on top of the target's global rotation. Updated automatically when dragging rotation in follow mode.

@export_category("Look At")
@export var use_look_at: bool = false ## Point toward look_at_target plus look_at_offset_deg. Dragging with R adjusts the offset relative to the aim line.
@export var look_at_target: Node2D ## World point or node to aim at. If missing or coincident with this marker, current rotation is kept.
@export var look_at_offset_deg: float = 0.0 ## Extra degrees added after aiming at the target. Mirrored when invert_rotation_on_flip applies.

@export_category("Ground Lock")
@export var use_ground_lock: bool = false ## Blend rotation toward ground_lock_rotation_deg as the marker moves down between ground_lock_upper and ground_lock_lower.
@export var ground_lock_upper: Node2D ## Y threshold where ground lock begins (0% blend). Leave empty to use lower.y minus ground_lock_falloff.
@export var ground_lock_lower: Node2D ## Y threshold where ground lock is fully applied (100% blend). Required for ground lock to run.
@export var ground_lock_rotation_deg: float = 0.0 ## Rotation (degrees, world space) used when fully grounded.
@export var ground_lock_falloff: float = 32.0 ## Vertical distance (pixels) above ground_lock_lower used when ground_lock_upper is not set.

var is_dragging_position: bool = false
var is_dragging_rotation: bool = false
var mouse_over: bool = false
var is_active: bool = false

var _prepare_drag_position: bool = false
var _prepare_drag_rotation: bool = false
var _mouse_start_pos: Vector2 = Vector2.ZERO
var _drag_offset: Vector2 = Vector2.ZERO

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
	process_priority = 100
	area_2d.mouse_entered.connect(func(): mouse_over = true)
	area_2d.mouse_exited.connect(func(): mouse_over = false)
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = outer_radius
	if slave:
		global_position = slave.global_position
		_sync_marker_rotation_from_slave()
		_sync_constraint_offsets_from_rotation()
	set_active(false)
	if is_controlled:
		take_control()
	else:
		release_control()

func set_active(active: bool) -> void:
	is_active = active
	if not is_active:
		_reset_marker_ui()

func take_control() -> void:
	is_controlled = true
	_sync_slave_freeze()
	if not slave:
		return
	slave.linear_velocity = Vector2.ZERO
	slave.angular_velocity = 0.0
	global_position = slave.global_position
	_sync_marker_rotation_from_slave()

func release_control() -> void:
	is_controlled = false
	_sync_slave_freeze()

func _sync_slave_freeze() -> void:
	if slave:
		slave.freeze = is_controlled

func _process(_delta: float) -> void:
	if not is_dev_mode:
		return
	_update_visuals()
	_handle_drag_input()
	if is_controlled and slave:
		constrain_global_position(global_position)

func _update_visuals() -> void:
	inner_circle_uncontrolled.visible = not is_controlled
	rotation_indicator_uncontrolled.visible = not is_controlled and can_rotate
	inner_circle_controlled.visible = is_controlled
	rotation_indicator_controlled.visible = is_controlled and can_rotate
	inner_circle_selected.visible = is_active
	rotation_indicator_selected.visible = is_active and can_rotate
	outer_rotation_ring.visible = is_active and can_rotate and is_controlled

func _handle_drag_input() -> void:
	var mouse_pos := get_global_mouse_position()
	if _prepare_drag_position and not is_dragging_position:
		if mouse_pos.distance_to(_mouse_start_pos) > drag_threshold:
			_capture_original_state()
			is_dragging_position = true
	if _prepare_drag_rotation and not is_dragging_rotation:
		if mouse_pos.distance_to(_mouse_start_pos) > drag_threshold:
			_capture_original_state()
			is_dragging_rotation = true
	if is_dragging_position:
		var target_pos := mouse_pos - _drag_offset
		var old_pos := global_position
		var constrained := _apply_position_constraints(target_pos)
		global_position = constrained
		if slave and is_controlled:
			slave.global_position = constrained
		var delta_pos := constrained - old_pos
		if delta_pos != Vector2.ZERO:
			dragged_position.emit(delta_pos)
	elif is_dragging_rotation:
		var delta_rot := 0.0
		if _is_ground_fully_locked():
			pass
		elif use_look_at and look_at_target and is_instance_valid(look_at_target):
			var aim_point := look_at_target.global_position
			if global_position.distance_squared_to(aim_point) > 0.01:
				var base_aim := global_position.angle_to_point(aim_point)
				var target_rot := global_position.angle_to_point(mouse_pos)
				var new_offset := rad_to_deg(target_rot - base_aim)
				delta_rot = deg_to_rad(new_offset - look_at_offset_deg)
				look_at_offset_deg = new_offset
		elif use_follow_rotation and follow_rotation_target and is_instance_valid(follow_rotation_target):
			var base_rot := follow_rotation_target.global_rotation
			var target_rot := global_position.angle_to_point(mouse_pos)
			var new_offset := rad_to_deg(target_rot - base_rot)
			delta_rot = deg_to_rad(new_offset - follow_rotation_offset_deg)
			follow_rotation_offset_deg = new_offset
		else:
			var target_rot := global_position.angle_to_point(mouse_pos)
			delta_rot = target_rot - _get_pose_world_rotation()
			if delta_rot != 0.0:
				rotation += delta_rot
		if delta_rot != 0.0:
			dragged_rotation.emit(delta_rot)

func _physics_process(_delta: float) -> void:
	if not slave:
		return
	_sync_slave_freeze()
	if is_controlled:
		constrain_global_position(global_position)
		var pose_rot := _solve_rotation()
		slave.global_rotation = _to_slave_rotation(pose_rot)
		_sync_marker_rotation_from_pose(pose_rot)
	else:
		global_position = slave.global_position
		if constrain_rotation_when_uncontrolled and _has_active_rotation_constraints():
			var pose_rot := _solve_rotation()
			slave.global_rotation = _to_slave_rotation(pose_rot)
			slave.angular_velocity = 0.0
			_sync_marker_rotation_from_pose(pose_rot)
		else:
			global_rotation = _from_slave_rotation(slave.global_rotation)

func constrain_global_position(pos: Vector2) -> Vector2:
	var result := _apply_position_constraints(pos)
	global_position = result
	if slave and is_controlled:
		slave.global_position = result
	return result

func _apply_position_constraints(pos: Vector2) -> Vector2:
	var result := pos
	if use_radius_limit:
		var origin := _radius_constraint_origin()
		if result.distance_to(origin) > max_radius:
			if is_dragging_position and _move_radius_drag_partner(result, origin):
				pass
			else:
				result = origin + (result - origin).normalized() * max_radius
	if use_min_max_x:
		var ref_x := x_constraint_parent.global_position.x if x_constraint_parent else 0.0
		result.x = clamp(result.x, ref_x + min_x, ref_x + max_x)
	if use_min_max_y:
		var ref_y := y_constraint_parent.global_position.y if y_constraint_parent else 0.0
		result.y = clamp(result.y, ref_y + min_y, ref_y + max_y)
	return result

func _radius_constraint_origin() -> Vector2:
	if radius_is_global or not radius_constraint_parent:
		return Vector2.ZERO
	return radius_constraint_parent.global_position

func _move_radius_drag_partner(driver_pos: Vector2, anchor: Vector2) -> bool:
	if not radius_drag_partner or not is_instance_valid(radius_drag_partner):
		return false
	if not radius_drag_partner.is_controlled or radius_drag_partner.is_dragging_position:
		return false
	var partner_pos := driver_pos + (anchor - driver_pos).normalized() * max_radius
	radius_drag_partner.constrain_global_position(partner_pos)
	return true

func _solve_rotation() -> float:
	var target := _resolve_ungrounded_rotation()
	var blend := _ground_lock_blend()
	if blend > 0.0:
		target = lerp_angle(target, deg_to_rad(ground_lock_rotation_deg), blend)
	return target

func _is_facing_flipped() -> bool:
	return pivot != null and is_instance_valid(pivot) and pivot.scale.x < 0

## Pose-space → ragdoll world rotation (flip correction applied once at the slave boundary).
func _to_slave_rotation(pose_rotation: float) -> float:
	if not _should_compensate_slave_rotation():
		return pose_rotation
	return pose_rotation + deg_to_rad(flip_rotation_compensation_deg)

func _from_slave_rotation(slave_rotation: float) -> float:
	if not _should_compensate_slave_rotation():
		return slave_rotation
	return slave_rotation - deg_to_rad(flip_rotation_compensation_deg)

func _should_compensate_slave_rotation() -> bool:
	if not invert_rotation_on_flip or not _is_facing_flipped():
		return false
	if use_follow_rotation:
		return false
	return true

## World rotation used to drive the ragdoll slave.
func _get_pose_world_rotation() -> float:
	# Under FacingPivot, read decomposed global rotation. Summing locals ignores
	# scale.x mirror, and assigning global_position each frame can shift local
	# rotation while global_rotation stays stable.
	return global_rotation

func _uses_authored_world_rotation() -> bool:
	if use_look_at and look_at_target and is_instance_valid(look_at_target):
		if global_position.distance_squared_to(look_at_target.global_position) > 0.01:
			return false
	if use_follow_rotation and follow_rotation_target and is_instance_valid(follow_rotation_target):
		return false
	return pivot != null and is_instance_valid(pivot) and pivot.is_ancestor_of(self)

func _sync_marker_rotation_from_slave() -> void:
	if not slave:
		return
	global_rotation = _from_slave_rotation(slave.global_rotation)

func _sync_marker_rotation_from_pose(pose_rot: float) -> void:
	# Writing global_rotation under a flipped parent corrupts local rotation when
	# the solve reads that local chain back on the next frame.
	if _uses_authored_world_rotation():
		return
	global_rotation = pose_rot

func _effective_look_at_offset_deg() -> float:
	if invert_rotation_on_flip and _is_facing_flipped():
		return -look_at_offset_deg
	return look_at_offset_deg

func _resolve_ungrounded_rotation() -> float:
	var rot_base := _rotation_limit_base()
	var target: float
	if use_look_at and look_at_target and is_instance_valid(look_at_target):
		var aim_point := look_at_target.global_position
		if global_position.distance_squared_to(aim_point) > 0.01:
			target = global_position.angle_to_point(aim_point) + deg_to_rad(_effective_look_at_offset_deg())
		else:
			target = _get_pose_world_rotation()
	elif use_follow_rotation and follow_rotation_target and is_instance_valid(follow_rotation_target):
		target = follow_rotation_target.global_rotation + deg_to_rad(follow_rotation_offset_deg)
	else:
		target = _get_pose_world_rotation()
	if use_rotation_limit:
		var base := rot_base.global_rotation if rot_base else 0.0
		var local: float = clamp(wrapf(rad_to_deg(target - base), -180.0, 180.0), min_rotation_deg, max_rotation_deg)
		target = base + deg_to_rad(local)
	return target

func _has_active_rotation_constraints() -> bool:
	return use_look_at or use_ground_lock or use_follow_rotation or use_rotation_limit

func _ground_lock_blend() -> float:
	if not use_ground_lock:
		return 0.0
	var lower := ground_lock_lower
	if not lower or not is_instance_valid(lower):
		return 0.0
	var lower_y := lower.global_position.y
	var upper_y := lower_y - ground_lock_falloff
	if ground_lock_upper and is_instance_valid(ground_lock_upper):
		upper_y = ground_lock_upper.global_position.y
	if upper_y >= lower_y:
		return 1.0 if global_position.y >= lower_y else 0.0
	if global_position.y <= upper_y:
		return 0.0
	if global_position.y >= lower_y:
		return 1.0
	return (global_position.y - upper_y) / (lower_y - upper_y)

func _is_ground_fully_locked() -> bool:
	return _ground_lock_blend() >= 1.0

func _rotation_limit_base() -> Node2D:
	if rotation_constraint_parent:
		return rotation_constraint_parent
	if use_follow_rotation and follow_rotation_target:
		return follow_rotation_target
	return null

func sync_constraint_offsets_from_rotation() -> void:
	_sync_constraint_offsets_from_rotation()

func _sync_constraint_offsets_from_rotation() -> void:
	var pose_rot := _get_pose_world_rotation()
	if use_follow_rotation and follow_rotation_target and is_instance_valid(follow_rotation_target):
		follow_rotation_offset_deg = rad_to_deg(wrapf(pose_rot - follow_rotation_target.global_rotation, -PI, PI))
	if use_look_at and look_at_target and is_instance_valid(look_at_target):
		var aim_point := look_at_target.global_position
		if global_position.distance_squared_to(aim_point) > 0.01:
			var base_aim := global_position.angle_to_point(aim_point)
			look_at_offset_deg = rad_to_deg(wrapf(pose_rot - base_aim, -PI, PI))

func _input(event: InputEvent) -> void:
	if not is_dev_mode:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos := get_global_mouse_position()
		if event.pressed and mouse_over:
			var distance := global_position.distance_to(mouse_pos)
			if distance <= outer_radius:
				selected.emit(self)
			if distance <= inner_radius:
				_mouse_start_pos = mouse_pos
				if Input.is_key_pressed(KEY_R) and can_rotate and outer_rotation_ring.visible:
					_prepare_drag_rotation = true
				else:
					_drag_offset = mouse_pos - global_position
					_prepare_drag_position = true
				get_viewport().set_input_as_handled()
			elif distance <= outer_radius and outer_rotation_ring.visible:
				_mouse_start_pos = mouse_pos
				_prepare_drag_rotation = true
				get_viewport().set_input_as_handled()
		elif not event.pressed:
			var was_dragging := is_dragging_position or is_dragging_rotation
			is_dragging_position = false
			is_dragging_rotation = false
			_prepare_drag_position = false
			_prepare_drag_rotation = false
			if was_dragging:
				_show_unsaved_state()
				drag_ended.emit(self)

func _capture_original_state() -> void:
	if has_unsaved_changes:
		return
	original_position = global_position
	original_rotation = rotation if _uses_authored_world_rotation() else global_rotation
	has_unsaved_changes = true

func _show_unsaved_state() -> void:
	var color := Color(1.0, 0.5, 0.0)
	if inner_circle_selected:
		inner_circle_selected.modulate = color
	if outer_rotation_ring:
		outer_rotation_ring.modulate = color

func _reset_marker_ui() -> void:
	has_unsaved_changes = false
	if inner_circle_selected:
		inner_circle_selected.modulate = Color.WHITE
	if outer_rotation_ring:
		outer_rotation_ring.modulate = Color.WHITE

func revert_to_original() -> void:
	if not has_unsaved_changes:
		return
	global_position = original_position
	if _uses_authored_world_rotation():
		rotation = original_rotation
	else:
		global_rotation = original_rotation
	_reset_marker_ui()
