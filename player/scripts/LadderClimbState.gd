extends PlayerState

func physics_update(_delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	var y_dir := Input.get_axis("ui_up", "ui_down")
	var is_moving := (y_dir != 0 or direction != 0)
	
	# Animation scaling
	if "parameters/ClimbScale/scale" in player.animator.tree:
		player.animator.tree["parameters/ClimbScale/scale"] = 1.0 if is_moving else 0.0
	
	player.velocity.y = y_dir * player.LADDER_CLIMB_SPEED
	player.velocity.x = direction * (player.SPEED * 0.5)
	
	# Jump off ladder
	if player.jump_buffer_timer > 0:
		player.jump_buffer_timer = 0
		player.velocity.y = player.JUMP_VELOCITY
		if "parameters/ClimbScale/scale" in player.animator.tree:
			player.animator.tree["parameters/ClimbScale/scale"] = 1.0
		state_machine.transition_to("air")
		return
		
	# Climb down to floor
	if player.is_on_floor() and y_dir > 0:
		if "parameters/ClimbScale/scale" in player.animator.tree:
			player.animator.tree["parameters/ClimbScale/scale"] = 1.0
		state_machine.transition_to("ground")
		return
