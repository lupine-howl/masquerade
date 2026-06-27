extends PlayerState

func enter() -> void:
	# Default to idle with a quick 0.1s blend when we land
	player.animator.play("idle", 0.1)
	if not player.is_inside_tree(): return
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(_on_respawn_timeout)


func physics_update(delta: float) -> void:
	
	player.animator.stop()
	player.ragdoll.set_ragdoll_state(player.ragdoll.RagdollState.FULL_BODY)
	player.ragdoll.root.freeze = false

	
	# Apply death friction (sliding to a halt)
	player.velocity.x = move_toward(player.velocity.x, 0, player.SPEED * delta * 4.0)
	
	# Apply gravity so the player falls if they die mid-air
	var current_gravity := player.get_gravity()
	if not player.is_on_floor():
		if player.is_submerged and current_gravity.y == ProjectSettings.get_setting("physics/2d/default_gravity"):
			player.velocity.y = min(player.velocity.y + current_gravity.y * player.water_gravity_multiplier * delta, player.water_terminal_velocity)
		else:
			player.velocity.y += current_gravity.y * delta

func _on_respawn_timeout() -> void:
	# Cleanly tell the manager to lock the anchors and snap back tracking before ground state takes over
	player.ragdoll.set_ragdoll_state(player.ragdoll.RagdollState.ANIMATED)
	
	state_machine.transition_to("ground")
	GameManager.trigger_player_respawn()
