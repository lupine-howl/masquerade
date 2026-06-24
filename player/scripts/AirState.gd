extends PlayerState

func physics_update(delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	
	# Horizontal Air Movement
	var current_target_speed := player.SPEED
	if player.is_submerged: current_target_speed *= player.water_speed_multiplier
	var horiz_gravity := player.get_gravity().x
	
	if direction != 0: 
		var adaptive_target_speed: float = direction * current_target_speed + (horiz_gravity * 0.25)
		player.velocity.x = move_toward(player.velocity.x, adaptive_target_speed, player.SPEED * 8 * delta)
		
		# Facing
		var new_facing = -1 if direction < 0 else 1
		if new_facing != player.facing: 
			player.facing = new_facing
			player.sprite_pivot.scale.x = player.facing
			for child in get_tree().get_nodes_in_group("flip_on_facing_change"):
				child.flip_h = (new_facing == -1)
	else: 
		player.velocity.x = move_toward(player.velocity.x, horiz_gravity * 0.5, current_target_speed * 8 * delta)

	# Animation Handling (Jumping vs Falling)
	if player.velocity.y < 0:
		player.animator.set_condition("jumping", true)
		player.animator.set_condition("falling", false)
	else:
		player.animator.set_condition("jumping", false)
		player.animator.set_condition("falling", true)

	# Jump Buffering & Double Jump
	if player.jump_buffer_timer > 0:
		if player.is_submerged:
			player.jump_buffer_timer = 0
			player.velocity.y = player.water_swim_velocity
		elif player.can_double_jump:
			player.jump_buffer_timer = 0
			player.can_double_jump = false
			player.velocity.y = player.DOUBLE_JUMP_VELOCITY
			player.animator.set_condition("double_jumping", true) # Active animation burst

	# Dash Transition
	if Input.is_action_just_pressed("ui_dash") and not player.is_submerged:
		state_machine.transition_to("dash")
		return

	# Ground Transition
	if player.is_on_floor() and player.velocity.y >= 0:
		state_machine.transition_to("ground")
		return
