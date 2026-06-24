extends PlayerState

func physics_update(_delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	var y_dir := Input.get_axis("ui_up", "ui_down")

	player.velocity.y = y_dir * player.WALL_CLIMB_SPEED
	player.velocity.x = 0 
	
	var pulling_away: bool = (direction != 0 and sign(direction) != player.facing)
	
	# Fall off wall
	if not player.wall_detector.is_colliding() or pulling_away:
		state_machine.transition_to("air")
		return
		
	# Wall Jump
	if player.jump_buffer_timer > 0:
		player.jump_buffer_timer = 0
		player.velocity.y = player.JUMP_VELOCITY * 0.85
		player.velocity.x = -player.facing * player.SPEED * 2.0 
		player.facing = -player.facing
		player.sprite_pivot.scale.x = player.facing 
		player.wall_jump_lock = 1.00
		state_machine.transition_to("air")
		return

	# Slide down to floor
	if player.is_on_floor():
		state_machine.transition_to("ground")
		return
