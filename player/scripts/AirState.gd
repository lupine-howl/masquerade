extends PlayerState

func enter() -> void:
	# Keep those arms floppy while airborne!
	if player.ragdoll and player.ragdoll.has_method("enable_arms"):
		player.ragdoll.enable_arms()

	# Decide what animation to start with based on our vertical momentum
	if player.velocity.y < 0:
		player.animator.play("jump", 0.1)
	else:
		player.animator.play("fall", 0.1)

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

	# --- ANIMATION LOGIC ---
	if player.velocity.y >= 0:
		player.animator.play("fall", 0.1)

	# Jump Buffering & Double Jump
	if player.jump_buffer_timer > 0:
		if player.is_submerged:
			player.jump_buffer_timer = 0
			player.velocity.y = player.water_swim_velocity
			player.animator.play("jump", 0.1) 
		elif player.can_double_jump:
			player.jump_buffer_timer = 0
			player.can_double_jump = false
			player.velocity.y = player.DOUBLE_JUMP_VELOCITY
			
			# Snap instantly to the double jump animation
			player.animator.play("double_jump", 0.0) 
			
			# Re-verify arm ragdolling in case the double_jump animation track 
			# has any stray keyframes trying to reset visibility
			if player.ragdoll and player.ragdoll.has_method("enable_arms"):
				player.ragdoll.enable_arms()

	# Dash Transition
	if Input.is_action_just_pressed("ui_dash") and not player.is_submerged:
		state_machine.transition_to("dash")
		return

	# Ground Transition
	if player.is_on_floor() and player.velocity.y >= 0:
		state_machine.transition_to("ground")
		return
