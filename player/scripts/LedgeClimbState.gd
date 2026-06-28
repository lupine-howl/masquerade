extends PlayerState

func enter() -> void:
	# Engage Hanging layout: Torso, legs, and back arm drop loose under gravity,
	# while the front arm/hand stays locked firmly to the ledge anchor.
	player.ragdoll.set_ragdoll_state(player.ragdoll.RagdollState.ANIMATED)

	player.animator.play("ledge_climb", 0.0)
	player.velocity = Vector2.ZERO
	
	var wall_intersection_pt: Vector2 = player.wall_detector.get_collision_point()
	
	# Snap the player into the exact hanging position
	player.global_position.x = wall_intersection_pt.x - (player.facing * 40.0)
	player.global_position.y = wall_intersection_pt.y + 150.0
	
	# Listen for the exact moment the animation finishes
	if not player.animator.anim_player.animation_finished.is_connected(_on_animation_finished):
		player.animator.anim_player.animation_finished.connect(_on_animation_finished)

func physics_update(_delta: float) -> void:
	# Keep the player perfectly still while the ledge climb animation plays.
	player.velocity = Vector2.ZERO

func exit() -> void:
	# Always clean up signals when leaving a state to prevent memory leaks or ghost calls
	if player.animator.anim_player.animation_finished.is_connected(_on_animation_finished):
		player.animator.anim_player.animation_finished.disconnect(_on_animation_finished)

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "ledge_climb":
		_finalize_climb()

func _finalize_climb() -> void:
	# 1. Capture the current local offset of the armature before we move anything
	player.animator.stop()
	var armature_offset = player.armature.position

	# 2. Perform the root teleportation
	player.global_position += Vector2(50.0 * player.facing, -140.0)

	# 3. COMPENSATE: Immediately move the armature in the OPPOSITE direction
	player.armature.position = Vector2.ZERO

	player.get_node("MasterCollisionShape").disabled = false
	state_machine.transition_to("ground")
