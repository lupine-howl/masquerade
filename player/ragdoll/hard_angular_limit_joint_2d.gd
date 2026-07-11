extends PinJoint2D
class_name HardAngularLimitJoint2D

## Post-step clamp for PinJoint2D angular limits. Godot/Rapier enforce these softly;
## competing IK and pose constraints can still hyperextend the joint briefly.
@export var hard_limit_enabled: bool = true

func _ready() -> void:
	process_physics_priority = -10

func _physics_process(_delta: float) -> void:
	if not hard_limit_enabled or not angular_limit_enabled:
		return
	var body_a := get_node_or_null(node_a) as RigidBody2D
	var body_b := get_node_or_null(node_b) as RigidBody2D
	if body_a == null or body_b == null:
		return
	if body_a.freeze and body_b.freeze:
		return

	var rel_rot := _relative_rotation(body_a, body_b)
	var clamped := clampf(rel_rot, angular_limit_lower, angular_limit_upper)
	if is_equal_approx(rel_rot, clamped):
		return

	body_b.global_rotation += clamped - rel_rot
	body_b.angular_velocity = 0.0

func _relative_rotation(body_a: RigidBody2D, body_b: RigidBody2D) -> float:
	return wrapf(
		(body_a.global_transform.affine_inverse() * body_b.global_transform).get_rotation(),
		-PI,
		PI
	)
