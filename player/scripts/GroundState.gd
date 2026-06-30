extends PlayerState

func enter() -> void:
	# Default to idle with a quick 0.1s blend when we land
	player.animator.play("idle", 0.5)
	

func physics_update(delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	var y_dir := Input.get_axis("ui_up", "ui_down")

	# --- ANIMATION & RAGDOLL LOGIC (Context-Driven Enum Paradigm) ---
	if direction != 0:
		player.animator.play("run", 0.5)
	elif y_dir > 0:
		player.animator.play("hanging")
	else:
		player.animator.play("idle", 0.5)

	# 1. Handle Facing Direction
	if direction != 0:
		var new_facing = -1 if direction < 0 else 1
		if new_facing != player.facing: 
			player.facing = new_facing
			player.sprite_pivot.scale.x = player.facing
			for child in get_tree().get_nodes_in_group("flip_on_facing_change"):
				child.flip_h = (new_facing == -1)

	# 2. Handle Movement & Friction
	var current_target_speed := player.SPEED
	if player.is_submerged: current_target_speed *= player.water_speed_multiplier
	var horiz_gravity := player.get_gravity().x
	
	if direction != 0: 
		var adaptive_target_speed: float = direction * current_target_speed + (horiz_gravity * 0.25)
		player.velocity.x = move_toward(player.velocity.x, adaptive_target_speed, player.SPEED * 8 * delta)
	else: 
		if player.is_on_floor(): horiz_gravity *= player.grounded_horizontal_current_dampening
		player.velocity.x = move_toward(player.velocity.x, horiz_gravity * 0.5, current_target_speed * 8 * delta)

	# 3. Transitions out of GroundState
	if Input.is_action_just_pressed("ui_dash") and not player.is_submerged:
		state_machine.transition_to("dash")
		return

	if player.attack_timer > 0.0 and y_dir > 0 and not player.is_submerged:
		state_machine.transition_to("roll")
		return

	if player.jump_buffer_timer > 0:
		player.jump_buffer_timer = 0
		player.velocity.y = player.water_swim_velocity if player.is_submerged else player.JUMP_VELOCITY
		state_machine.transition_to("air") 
		return

	if not player.is_on_floor() and player.velocity.y >= 0: 
		state_machine.transition_to("air")
		return
