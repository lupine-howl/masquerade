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
@export var hide_in_pose_ui: bool = false ## Hide from the pose part list and on-screen gizmo. Marker still animates, constraints, and keys normally (for baking helpers).

@export_category("X-Axis Constraint")
@export var use_min_max_x: bool = false ## Clamp world X while the marker is controlled (and during drag before physics sync).
@export var min_x: float = -100.0 ## Minimum allowed X, relative to x_constraint_parent world X. Ignored when use_min_max_x is false.
@export var max_x: float = 100.0 ## Maximum allowed X, relative to x_constraint_parent world X. Ignored when use_min_max_x is false.
@export var x_constraint_parent: Node2D ## World X reference for min_x/max_x. Leave empty to use world origin (X = 0). Typically assign a torso or root body so limits move with the character.

@export_category("Y-Axis Constraint")
@export var use_min_max_y: bool = false ## Clamp world Y while the marker is controlled.
@export var min_y: float = -100.0 ## Minimum allowed Y, relative to y_constraint_parent world Y. Ignored when use_min_max_y is false.
@export var max_y: float = 100.0 ## Maximum allowed Y (floor when Y+ is down), relative to y_constraint_parent. Applied after radius limit.
@export var max_y_buffer: float = 80.0 ## Y offset where buffer rotation begins (absolute, same space as min_y/max_y). 0% rotation here, 100% at max_y.
@export var y_constraint_parent: Node2D ## World Y reference for min_y/max_y/max_y_buffer. Leave empty to use world origin (Y = 0).
@export var y_use_buffer_rotation: bool = false ## Blend rotation from y_buffer_rotation_deg as Y moves from max_y_buffer toward max_y.
@export var y_buffer_rotation_deg: float = 0.0 ## World rotation (degrees) when fully at max_y — e.g. foot flat on the floor.
@export var y_hard_buffer: bool = false ## When true, Y cannot rise above max_y_buffer (buffer is the hard lower clamp bound). max_y stays the floor. When false, buffer only affects rotation.

@export_category("Radius Constraint")
@export var use_radius_limit: bool = false ## Keep the marker between min_radius and max_radius of the radius origin.
@export var min_radius: float = 0.0 ## Minimum distance from the radius origin (world pixels). 0 = no inner bound.
@export var max_radius: float = 50.0 ## Maximum distance from the radius origin (pixels in world space).
@export var radius_is_global: bool = false ## When true, the origin is always world (0, 0). When false, uses radius_constraint_parent global position, or (0, 0) if that is also empty.
@export var radius_constraint_parent: Node2D ## Center of the radius limit in world space. Leave empty (with radius_is_global false) to anchor at world origin. Often the parent limb or torso.
@export var radius_drag_partner: PoseMarker ## Optional marker coupled to this radius. When this marker hits the limit while dragging, the partner is translated with the drag instead of snapping to the opposite arc.
@export var use_radius_angle_limit: bool = false ## Limit position to a world-angle arc around the radius origin (ignores parent rotation — good for eyeline targets).
@export var min_radius_angle_deg: float = -90.0 ## Minimum world angle (degrees) from origin → marker. 0° = east/right in Godot. Sticks when crossed (supports ranges beyond ±180, e.g. -270 to 90).
@export var max_radius_angle_deg: float = 90.0 ## Maximum world angle (degrees) from origin → marker.
@export var radius_keep_world_offset: bool = false ## Keep the same world X/Y offset from radius_constraint_parent when it translates. Ignores parent rotation. Skipped while dragging this marker.

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
var _radius_angle_unwrapped_deg: float = 0.0
var _radius_angle_state_valid: bool = false
var _radius_parent_world_offset: Vector2 = Vector2.ZERO
var _last_radius_parent_pos: Vector2 = Vector2.ZERO
var _radius_parent_follow_ready: bool = false

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
	_apply_pose_ui_visibility()

func is_interactive_in_pose_ui() -> bool:
	return is_dev_mode and not hide_in_pose_ui

func _apply_pose_ui_visibility() -> void:
	var show_gizmo := is_interactive_in_pose_ui()
	visible = show_gizmo
	if area_2d:
		area_2d.input_pickable = show_gizmo
	if not show_gizmo:
		set_active(false)
		is_dragging_position = false
		is_dragging_rotation = false
		_prepare_drag_position = false
		_prepare_drag_rotation = false

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
	if _should_compensate_path_guide() and not is_dragging_position:
		global_position -= _get_path_guide_compensation()
	if not is_dev_mode:
		return
	if is_interactive_in_pose_ui():
		_update_visuals()
		_handle_drag_input()
	if is_controlled and slave:
		_apply_radius_parent_offset_follow()
		constrain_global_position(global_position)
	elif _uses_position_constraints():
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
		var drag_delta := target_pos - old_pos
		var constrained := _apply_position_constraints(target_pos, drag_delta)
		global_position = constrained
		if slave and is_controlled:
			slave.global_position = constrained
		var delta_pos := constrained - old_pos
		if delta_pos != Vector2.ZERO:
			dragged_position.emit(delta_pos)
	elif is_dragging_rotation:
		var delta_rot := 0.0
		if _is_y_buffer_fully_rotated():
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

func _should_compensate_path_guide() -> bool:
	var player := _find_player()
	if player == null:
		return false
	if player.get_state_name() != "ledgeclimb":
		return false
	return PathGuideMarker.get_drive_body_guide(player) != null

func _get_path_guide_compensation() -> Vector2:
	var player := _find_player()
	if player == null:
		return Vector2.ZERO
	return PathGuideMarker.get_path_compensation_offset(player)

func _find_player() -> Player:
	var node: Node = self
	while node:
		if node is Player:
			return node as Player
		node = node.get_parent()
	return null

func _physics_process(_delta: float) -> void:
	if not slave:
		return
	_sync_slave_freeze()
	if is_controlled:
		_apply_radius_parent_offset_follow()
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

func constrain_global_position(pos: Vector2, drag_delta: Vector2 = Vector2.ZERO) -> Vector2:
	var result := _apply_position_constraints(pos, drag_delta)
	global_position = result
	if slave and is_controlled:
		slave.global_position = result
	return result

func _apply_position_constraints(pos: Vector2, drag_delta: Vector2 = Vector2.ZERO) -> Vector2:
	var result := pos
	if use_radius_limit:
		result = _apply_radius_constraints(result, drag_delta)
	if use_min_max_x:
		var ref_x := x_constraint_parent.global_position.x if x_constraint_parent else 0.0
		result.x = clamp(result.x, ref_x + min_x, ref_x + max_x)
	if use_min_max_y:
		var ref_y := y_constraint_parent.global_position.y if y_constraint_parent else 0.0
		var clamp_min_y := max_y_buffer if y_hard_buffer else min_y
		result.y = clamp(result.y, ref_y + clamp_min_y, ref_y + max_y)
	return result

func _uses_position_constraints() -> bool:
	return use_radius_limit or use_min_max_x or use_min_max_y

func _apply_radius_constraints(pos: Vector2, drag_delta: Vector2 = Vector2.ZERO) -> Vector2:
	var origin := _radius_constraint_origin()
	var offset := pos - origin
	var dist := offset.length()
	var angle_rad := offset.angle() if dist > 0.001 else deg_to_rad(min_radius_angle_deg)
	var dist_min := maxf(min_radius, 0.0)
	var dist_max := maxf(max_radius, dist_min)
	var was_beyond_max := dist > dist_max
	var was_inside_min := dist < dist_min and dist_min > 0.0

	if use_radius_angle_limit:
		angle_rad = deg_to_rad(_clamp_radius_angle_deg(rad_to_deg(angle_rad)))

	var clamped_dist := clampf(dist if dist > 0.001 else dist_min, dist_min, dist_max)
	var result := origin + Vector2.from_angle(angle_rad) * clamped_dist

	if is_dragging_position and drag_delta != Vector2.ZERO and radius_drag_partner:
		if was_beyond_max or was_inside_min:
			_move_radius_drag_partner(drag_delta)

	return result

func _radius_constraint_origin() -> Vector2:
	if radius_is_global or not radius_constraint_parent:
		return Vector2.ZERO
	return radius_constraint_parent.global_position

func _apply_radius_parent_offset_follow() -> void:
	if not use_radius_limit or not radius_keep_world_offset or radius_is_global:
		_radius_parent_follow_ready = false
		return
	var parent := radius_constraint_parent
	if not parent or not is_instance_valid(parent):
		_radius_parent_follow_ready = false
		return

	var parent_pos := parent.global_position

	if is_dragging_position:
		_radius_parent_world_offset = global_position - parent_pos
		_radius_parent_follow_ready = true
		_last_radius_parent_pos = parent_pos
		return

	if not _radius_parent_follow_ready:
		_radius_parent_world_offset = global_position - parent_pos
		_radius_parent_follow_ready = true
		_last_radius_parent_pos = parent_pos
		return

	var parent_delta := parent_pos - _last_radius_parent_pos
	var expected_pos := _last_radius_parent_pos + _radius_parent_world_offset

	if parent_delta != Vector2.ZERO:
		if global_position.is_equal_approx(expected_pos):
			var new_pos := global_position + parent_delta
			global_position = new_pos
			if slave and is_controlled:
				slave.global_position = new_pos
	elif not global_position.is_equal_approx(parent_pos + _radius_parent_world_offset):
		_radius_parent_world_offset = global_position - parent_pos

	_last_radius_parent_pos = parent_pos

func _invalidate_radius_parent_offset_follow() -> void:
	_radius_parent_follow_ready = false

func _unwrap_angle_toward(angle_deg: float, reference_deg: float) -> float:
	var a := angle_deg
	while a - reference_deg > 180.0:
		a -= 360.0
	while a - reference_deg < -180.0:
		a += 360.0
	return a

func _ensure_radius_angle_state(raw_deg: float) -> void:
	if _radius_angle_state_valid:
		return
	var lo := min_radius_angle_deg
	var hi := max_radius_angle_deg
	var mid := lo + (hi - lo) * 0.5
	var unwrapped := _unwrap_angle_toward(raw_deg, mid)
	_radius_angle_unwrapped_deg = clampf(unwrapped, lo, hi)
	_radius_angle_state_valid = true

func _clamp_radius_angle_deg(raw_deg: float) -> float:
	var lo := min_radius_angle_deg
	var hi := max_radius_angle_deg
	_ensure_radius_angle_state(raw_deg)
	var unwrapped := _unwrap_angle_toward(raw_deg, _radius_angle_unwrapped_deg)
	unwrapped = clampf(unwrapped, lo, hi)
	_radius_angle_unwrapped_deg = unwrapped
	_radius_angle_state_valid = true
	return unwrapped

func _move_radius_drag_partner(drag_delta: Vector2) -> void:
	var partner := radius_drag_partner
	if not partner or not is_instance_valid(partner):
		return
	if partner.is_dragging_position:
		return
	var partner_pos := partner.global_position + drag_delta
	var constrained := partner._apply_position_constraints(partner_pos)
	partner.global_position = constrained
	if partner.slave:
		partner.slave.global_position = constrained

func _solve_rotation() -> float:
	var target := _resolve_free_rotation()
	var blend := _y_buffer_rotation_blend()
	if blend > 0.0:
		target = lerp_angle(target, deg_to_rad(y_buffer_rotation_deg), blend)
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

func _resolve_free_rotation() -> float:
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
	return use_look_at or y_use_buffer_rotation or use_follow_rotation or use_rotation_limit

func _y_constraint_ref_y() -> float:
	return y_constraint_parent.global_position.y if y_constraint_parent else 0.0

func _y_buffer_world_y() -> float:
	return _y_constraint_ref_y() + max_y_buffer

func _y_max_world_y() -> float:
	return _y_constraint_ref_y() + max_y

func _y_buffer_rotation_blend() -> float:
	if not use_min_max_y or not y_use_buffer_rotation:
		return 0.0
	var buffer_y := _y_buffer_world_y()
	var max_limit_y := _y_max_world_y()
	var span := max_limit_y - buffer_y
	if span <= 0.001:
		return 1.0 if global_position.y >= max_limit_y - 0.001 else 0.0
	var y := global_position.y
	if y <= buffer_y:
		return 0.0
	if y >= max_limit_y:
		return 1.0
	return (y - buffer_y) / span

func _is_y_buffer_fully_rotated() -> bool:
	return _y_buffer_rotation_blend() >= 1.0

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
	if not is_interactive_in_pose_ui():
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
	if use_radius_limit and use_radius_angle_limit:
		var origin := _radius_constraint_origin()
		var offset := global_position - origin
		if offset.length_squared() > 0.001:
			_ensure_radius_angle_state(rad_to_deg(offset.angle()))
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
	_radius_angle_state_valid = false
	_invalidate_radius_parent_offset_follow()
	_reset_marker_ui()
