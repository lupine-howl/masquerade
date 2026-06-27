extends PlayerState

func enter() -> void:
	# Enforce absolute animation authority so the limbs snap firmly to the wall climb pose
	player.ragdoll.set_ragdoll_state(player.ragdoll.RagdollState.HANGING)

	# Snap instantly to the wall frame (0.0 blend time) so it doesn't 
	# get frozen in a crossfade by the speed_scale drop!
	player.animator.play("wall_climb", 0.0)

func physics_update(_delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	var y_dir := Input.get_axis("ui_up", "ui_down")
	
	player.ragdoll.front_hand.global_position = player.global_position + Vector2(player.facing*40,-130)
	player.ragdoll.back_hand.global_position = player.global_position + Vector2(player.facing*40,-130)
	player.ragdoll.back_hand.rotation_degrees = 90
	player.ragdoll.front_hand.rotation_degrees = 270
	player.ragdoll.back_hand.freeze = true
	player.ragdoll.front_hand.freeze = true
	player.ragdoll.root.freeze = false
	player.animator.stop()
	player.ragdoll.set_ragdoll_state(player.ragdoll.RagdollState.HANGING)

	# --- ANIMATION LOGIC ---
	var is_moving := (y_dir != 0)
	var anim_speed = 1.0 if is_moving else 0.0
	
	# Use 0.0 blend time here too, otherwise moving up/down might 
	# continuously try to restart a crossfade every frame.
	#player.animator.play("wall_climb", 0.0, anim_speed)

	# --- PHYSICS LOGIC ---
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
		
		# The AirState will automatically see we are moving up and play the jump animation!
		state_machine.transition_to("air")
		return

	# Slide down to floor
	if player.is_on_floor():
		state_machine.transition_to("ground")
		return
