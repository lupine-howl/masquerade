extends PlayerState

const GRAB_OFFSET_X := 80

## Seconds to slide up the wall (phase 1). Match this span in ledge_climb keys.
@export var vertical_duration := 0.3
## Seconds to step forward onto the ledge (phase 2).
@export var forward_duration := 0.3
## World pixels to rise during phase 1. 0 = one capsule height.
@export var vertical_rise := 0.0
## World pixels to move onto the platform during phase 2 (facing-aware).
@export var forward_offset := 120.0
## Extra Y applied to the final position (negative = higher).
@export var end_height_adjust := 0.0
## Stretch ledge_climb playback so clip length matches vertical + forward duration.
@export var auto_match_anim_duration := true

var _start_pos := Vector2.ZERO
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

	var capsule_size: Vector2 = player.get_body_capsule_size()
	var radius: float = capsule_size.x
	var half_height: float = capsule_size.y * 0.5

	var wall_pt: Vector2 = player.wall_detector.get_collision_point()
	player.global_position.x = wall_pt.x - (player.facing * GRAB_OFFSET_X)
	player.global_position.y = wall_pt.y + half_height - radius

	_setup_climb_path()

	player.animator.play("ledge_climb", 0.0)
	if auto_match_anim_duration:
		call_deferred("_match_anim_speed_to_movement")

func physics_update(delta: float) -> void:
	player.velocity = Vector2.ZERO
	if _finalized:
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
	if player.master_collision_shape:
		player.master_collision_shape.disabled = false
	player.armature.position = Vector2.ZERO

func get_total_duration() -> float:
	return vertical_duration + forward_duration

## Normalized climb progress 0→1 for debugging or pose reference.
func get_move_progress() -> float:
	var total := get_total_duration()
	if total <= 0.0:
		return 1.0
	return clampf(_elapsed / total, 0.0, 1.0)

func _match_anim_speed_to_movement() -> void:
	if not player.animator.has_animation("ledge_climb"):
		return
	var anim := player.animator.get_animation("ledge_climb")
	var move_duration := get_total_duration()
	if anim.length <= 0.0 or move_duration <= 0.0:
		return
	player.animator.speed_scale *= anim.length / move_duration

func _setup_climb_path() -> void:
	_start_pos = player.global_position
	var rise := vertical_rise if vertical_rise > 0.0 else player.get_body_capsule_height() - 60.0
	_rise_pos = _start_pos + Vector2(0.0, -rise)
	_end_pos = _rise_pos + Vector2(forward_offset * player.facing, end_height_adjust)

func _finalize_climb() -> void:
	if _finalized:
		return
	_finalized = true
	player.global_position = _end_pos
	if player.animator.has_animation("idle"):
		player.animator.play("idle", 0.0)
	else:
		player.animator.stop()
	state_machine.transition_to("ground")
