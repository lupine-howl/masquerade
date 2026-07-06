extends PlayerState

const GRAB_OFFSET_X := 80

## When set and role is DRIVE_BODY, body follows this guide's keyed path instead of the lerp below.
@export var path_guide: PathGuideMarker
@export var use_path_guide := true

## Fallback scripted path when no path guide is used.
@export var vertical_duration := 0.3
@export var forward_duration := 0.3
@export var vertical_rise := 0.0
@export var forward_offset := 120.0
@export var end_height_adjust := 0.0
@export var auto_match_anim_duration := true

var _start_pos := Vector2.ZERO
var _path_origin := Vector2.ZERO
var _rise_pos := Vector2.ZERO
var _end_pos := Vector2.ZERO
var _elapsed := 0.0
var _finalized := false

func enter() -> void:
	_finalized = false
	_elapsed = 0.0
	player.velocity = Vector2.ZERO
	player.armature.position = Vector2.ZERO

	var collision_shape: CollisionShape2D = player.master_collision_shape
	if collision_shape:
		collision_shape.disabled = true

	var radius: float = player.get_body_capsule_radius()
	var half_extent_y: float = player.get_body_capsule_half_extent_y()

	var wall_pt: Vector2 = player.wall_detector.get_collision_point()
	player.global_position.x = wall_pt.x - (player.facing * GRAB_OFFSET_X)
	player.global_position.y = wall_pt.y

	_start_pos = player.global_position

	if _uses_path_guide():
		_begin_path_guide_climb()
	else:
		_setup_climb_lerp()
		player.animator.play("ledge_climb", 0.0)
		if auto_match_anim_duration:
			call_deferred("_match_anim_speed_to_movement")

func physics_update(delta: float) -> void:
	player.velocity = Vector2.ZERO
	if _finalized:
		return

	if _uses_path_guide():
		player.global_position = _path_origin + path_guide.get_climb_offset(player.facing)
		return

	_elapsed += delta
	var rise_time := maxf(vertical_duration, 0.0001)
	var forward_time := maxf(forward_duration, 0.0001)

	if _elapsed <= rise_time:
		var t := clampf(_elapsed / rise_time, 0.0, 1.0)
		player.global_position = _start_pos.lerp(_rise_pos, t)
	elif _elapsed <= rise_time + forward_time:
		var t := clampf((_elapsed - rise_time) / forward_time, 0.0, 1.0)
		player.global_position = _rise_pos.lerp(_end_pos, t)
	else:
		player.global_position = _end_pos
		_finalize_climb()

func exit() -> void:
	if player.animator.animation_finished.is_connected(_on_animation_finished):
		player.animator.animation_finished.disconnect(_on_animation_finished)
	if path_guide and path_guide.anchor:
		path_guide.anchor.release_lock()
	if player.master_collision_shape:
		player.master_collision_shape.disabled = false
	player.armature.position = Vector2.ZERO

func get_total_duration() -> float:
	if _uses_path_guide() and player.animator.has_animation("ledge_climb"):
		return player.animator.get_animation("ledge_climb").length
	return vertical_duration + forward_duration

func _uses_path_guide() -> bool:
	return (
		use_path_guide
		and path_guide != null
		and path_guide.role == PathGuideMarker.Role.DRIVE_BODY
	)

func _begin_path_guide_climb() -> void:
	_path_origin = _start_pos
	if path_guide.anchor:
		path_guide.anchor.lock_at(_path_origin)
	path_guide.position = Vector2.ZERO
	if not player.animator.animation_finished.is_connected(_on_animation_finished):
		player.animator.animation_finished.connect(_on_animation_finished)
	player.animator.play("ledge_climb", 0.0)
	player.animator.seek(0.0, true)

func _on_animation_finished(anim_name: StringName) -> void:
	if String(anim_name) == "ledge_climb" and _uses_path_guide():
		_finalize_climb()

func _setup_climb_lerp() -> void:
	var rise := vertical_rise if vertical_rise > 0.0 else player.get_body_capsule_height() - 60.0
	_rise_pos = _start_pos + Vector2(0.0, -rise)
	_end_pos = _rise_pos + Vector2(forward_offset * player.facing, end_height_adjust)

func _match_anim_speed_to_movement() -> void:
	if not player.animator.has_animation("ledge_climb"):
		return
	var anim: Animation = player.animator.get_animation("ledge_climb")
	var move_duration := get_total_duration()
	if anim.length <= 0.0 or move_duration <= 0.0:
		return
	player.animator.speed_scale *= anim.length / move_duration

func _finalize_climb() -> void:
	if _finalized:
		return
	_finalized = true
	if _uses_path_guide():
		player.global_position = _path_origin + path_guide.get_climb_offset(player.facing)
	else:
		player.global_position = _end_pos
	if player.animator.has_animation("idle"):
		player.animator.play("idle", 0.0)
	else:
		player.animator.stop()
	state_machine.transition_to("ground")
