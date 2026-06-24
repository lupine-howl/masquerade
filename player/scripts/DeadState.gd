extends PlayerState

func enter() -> void:
	# Trigger the animation instantly
	player.animator.play("dead") 
	
	# Optional but recommended: Disable hitboxes/hurtboxes so enemies don't keep hitting a corpse
	# player.get_node("CollisionShape2D").set_deferred("disabled", true)
	
	# Create our respawn timer safely
	if not player.is_inside_tree(): return
	var timer = get_tree().create_timer(1.2)
	timer.timeout.connect(_on_respawn_timeout)

func physics_update(delta: float) -> void:
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
	# Re-enable collision if you disabled it above
	# player.get_node("CollisionShape2D").set_deferred("disabled", false)
	
	state_machine.transition_to("ground")
	GameManager.trigger_player_respawn()
