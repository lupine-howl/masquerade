extends Node2D

@export_category("Ragdoll Mapping")
# Ensure the order matches exactly! Index 0 Body MUST map to Index 0 Bone.
@export var ragdoll_bodies: Array[RigidBody2D] = []
@export var skeleton_bones: Array[Bone2D] = []

@export_category("Skeletal Systems")
@export var skeleton_node: Skeleton2D
@export var animator: Node

var is_ragdoll_active: bool = true

func _ready() -> void:
	# A safety check. If you mess up the Inspector setup, the game warns you immediately.
	assert(ragdoll_bodies.size() == skeleton_bones.size(), "Ragdoll setup error: Body and Bone arrays must be the exact same size.")
	
	# Initialize default state
	enable()

func _process(_delta: float) -> void:
	# If we aren't limp, do nothing. Let the AnimationPlayer do its job.
	if not is_ragdoll_active:
		return

	# A single, clean loop handles the entire skeletal sync
	for i in range(ragdoll_bodies.size()):
		var body = ragdoll_bodies[i]
		var bone = skeleton_bones[i]

		if body and bone:
			bone.global_rotation = body.global_rotation
			# bone.global_position = body.global_position

func enable() -> void:
	is_ragdoll_active = true
	
	# Explicitly disable specific IK modifiers by index when ragdoll turns on
	# (e.g., if index 0 is your Left Arm IK, and index 1 is your Right Arm IK)
	set_ik_modifier_enabled(2, false)
	set_ik_modifier_enabled(3, false)

func disable() -> void:
	is_ragdoll_active = false
	
	# Explicitly re-enable specific IK modifiers by index when ragdoll turns off
	set_ik_modifier_enabled(2, true)
	set_ik_modifier_enabled(3, true)

## Helper function to safely locate and toggle an IK modifier by its index position
func set_ik_modifier_enabled(index: int, should_enable: bool) -> void:
	if not skeleton_node:
		return
		
	var stack = skeleton_node.get_modification_stack()
	if stack and index >= 0 and index < stack.modification_count:
		var modifier = stack.get_modification(index)
		if modifier:
			modifier.enabled = should_enable
