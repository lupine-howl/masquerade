extends PlayerState

const GRAB_OFFSET_X := 80
const CLIMB_ANIM := "ledge_climb"

## Fallback scripted path when the climb animation has no keyed path guide tracks.
@export var vertical_duration := 0.3
@export var forward_duration := 0.3
@export var vertical_rise := 0.0
@export var forward_offset := 120.0
@export var end_height_adjust := 0.0
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

	player.animator.play(CLIMB_ANIM, 0.0)
	if player.animator.is_path_body_driving():
		if not player.animator.path_body_finished.is_connected(_on_path_body_finished):
			player.animator.path_body_finished.connect(_on_path_body_finished)
		return

	var collision_shape: CollisionShape2D = player.master_collision_shape
	if collision_shape:
		collision_shape.disabled = true

	var wall_pt: Vector2 = player.wall_detector.get_collision_point()
	player.global_position.x = wall_pt.x - (player.facing * GRAB_OFFSET_X)
	player.global_position.y = wall_pt.y
	_start_pos = player.global_position
	_setup_climb_lerp()
	if auto_match_anim_duration:
		call_deferred("_match_anim_speed_to_movement")

func physics_update(delta: float) -> void:
	player.velocity = Vector2.ZERO
	if _finalized:
		return

	if player.animator.is_path_body_driving():
		player.animator.physics_update_path_body()
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
	if player.animator.path_body_finished.is_connected(_on_path_body_finished):
		player.animator.path_body_finished.disconnect(_on_path_body_finished)
	player.animator.end_path_body_drive()
	if player.master_collision_shape:
		player.master_collision_shape.disabled = false
	player.armature.position = Vector2.ZERO

func get_total_duration() -> float:
	if (
		PlayerAnimator.animation_has_path_guide_keys(player.animator, CLIMB_ANIM)
		and player.animator.has_animation(CLIMB_ANIM)
	):
		return player.animator.get_animation(CLIMB_ANIM).length
	return vertical_duration + forward_duration

func _on_path_body_finished(anim_name: String) -> void:
	if anim_name == CLIMB_ANIM:
		_finalize_climb()

func _setup_climb_lerp() -> void:
	var rise := vertical_rise if vertical_rise > 0.0 else player.get_body_capsule_height() - 60.0
	_rise_pos = _start_pos + Vector2(0.0, -rise)
	_end_pos = _rise_pos + Vector2(forward_offset * player.facing, end_height_adjust)

func _match_anim_speed_to_movement() -> void:
	if not player.animator.has_animation(CLIMB_ANIM):
		return
	var anim: Animation = player.animator.get_animation(CLIMB_ANIM)
	var move_duration := get_total_duration()
	if anim.length <= 0.0 or move_duration <= 0.0:
		return
	player.animator.speed_scale *= anim.length / move_duration

func _finalize_climb() -> void:
	if _finalized:
		return
	_finalized = true
	if player.animator.is_path_body_driving():
		player.animator.sync_path_body_position()
	else:
		player.global_position = _end_pos
	if player.animator.has_animation("idle"):
		player.animator.play("idle", 0.0)
	else:
		player.animator.stop()
	state_machine.transition_to("ground")
