extends PlayerState

func enter() -> void:
	# Start the climb animation paused (0.0 speed) until they press a direction
	player.animator.play("ladder_climb", 0.1, 0.0)

func physics_update(_delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	var y_dir := Input.get_axis("ui_up", "ui_down")
	var is_moving := (y_dir != 0 or direction != 0)
	
	# --- ANIMATION LOGIC ---
	var anim_speed = 1.0 if is_moving else 0.0
	# Use 0.0 blend time here so speed updates don't try to constantly restart a crossfade
	player.animator.play("ladder_climb", 0.0, anim_speed) 
	
	# --- PHYSICS LOGIC ---
	player.velocity.y = y_dir * player.LADDER_CLIMB_SPEED
	player.velocity.x = direction * (player.SPEED * 0.5)
	
	# Jump off ladder
	if player.jump_buffer_timer > 0:
		player.jump_buffer_timer = 0
		player.velocity.y = player.JUMP_VELOCITY
		
		# (AirState will automatically handle playing the jump animation)
		state_machine.transition_to("air")
		return
		
	# Climb down to floor
	if player.is_on_floor() and y_dir > 0:
		state_machine.transition_to("ground")
		return
