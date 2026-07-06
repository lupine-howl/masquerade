extends PlayerState

const GRAB_OFFSET_X := 40.0
const CLIMB_FORWARD_OFFSET := 50.0
const HEIGHT_OFFSET_Y := 20.0

var _ledge_anchor: Node2D
var _anchor_world_lock: Vector2

func enter() -> void:
	player.velocity = Vector2.ZERO
	player.animator.play("ledge_climb", 0.0)

	var collision_shape: CollisionShape2D = player.master_collision_shape
	if collision_shape:
		collision_shape.disabled = true

	var capsule_size: Vector2 = player.get_body_capsule_size()
	var radius: float = capsule_size.x
	var half_height: float = capsule_size.y * 0.5

	var wall_pt: Vector2 = player.wall_detector.get_collision_point()
	player.global_position.x = wall_pt.x - (player.facing * GRAB_OFFSET_X)
	player.global_position.y = wall_pt.y + half_height - radius

	_ledge_anchor = player.get_node_or_null("%LedgeAnchor") as Node2D
	if _ledge_anchor:
		_anchor_world_lock = _ledge_anchor.global_position

	if not player.animator.animation_finished.is_connected(_on_animation_finished):
		player.animator.animation_finished.connect(_on_animation_finished)

func physics_update(_delta: float) -> void:
	player.velocity = Vector2.ZERO
	_apply_ledge_anchor_root_motion()
	_absorb_armature_root_offset()

func exit() -> void:
	if player.animator.animation_finished.is_connected(_on_animation_finished):
		player.animator.animation_finished.disconnect(_on_animation_finished)
	if player.master_collision_shape:
		player.master_collision_shape.disabled = false
	_ledge_anchor = null

func _on_animation_finished(anim_name: StringName) -> void:
	if String(anim_name) == "ledge_climb":
		_finalize_climb()

## Works when the clip keys LedgeAnchor or any armature child that should stay world-fixed.
func _apply_ledge_anchor_root_motion() -> void:
	if _ledge_anchor == null:
		return
	var drift := _ledge_anchor.global_position - _anchor_world_lock
	if drift.is_zero_approx():
		return
	player.global_position -= drift

## Fold animated armature.position into the body so the clip can drive root motion.
func _absorb_armature_root_offset() -> void:
	var offset: Vector2 = player.armature.position
	if offset.is_zero_approx():
		return
	player.global_position += Vector2(offset.x * player.facing, offset.y)
	player.armature.position = Vector2.ZERO

func _finalize_climb() -> void:
	_absorb_armature_root_offset()
	player.global_position.x += CLIMB_FORWARD_OFFSET * player.facing
	# Body stays at wall-grab height during the clip; lift by one capsule height so
	# the collision volume clears the platform (HEIGHT_OFFSET_Y fine-tunes placement).
	player.global_position.y -= player.get_body_capsule_height() - HEIGHT_OFFSET_Y

	if player.animator.has_animation("idle"):
		player.animator.play("idle", 0.0)
	else:
		player.animator.stop()

	state_machine.transition_to("ground")
