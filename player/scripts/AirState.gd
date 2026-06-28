extends PlayerState

# Track whether the character has successfully left the ground yet
var is_launching: bool = false

func enter() -> void:
	is_launching = true
	
	if player.is_on_floor():
		# Capture our momentum: are we moving fast enough to warrant a running jump?
		var is_running: bool = abs(player.velocity.x) > (player.SPEED * 0.2)
		
		# Prevent the player from instantly sliding around weirdly during wind-up
		# But keep a bit of forward friction so they don't instantly slide-halt like a brick
		player.velocity.x *= 0.4 
		player.velocity.y = 0 

		# Play the targeted launch/crouch animation
		if is_running and player.animator.anim_player.has_animation("run_jump_launch"):
			player.animator.play("run_jump_launch")
		else:
			player.animator.play("jump_launch")
		
		# Keep them safely locked in animation framework during the push-off phase
		player.ragdoll.set_ragdoll_state(player.ragdoll.RagdollState.FULL_BODY )
		
		if not player.animator.anim_player.animation_finished.is_connected(_on_launch_animation_finished):
			player.animator.anim_player.animation_finished.connect(_on_launch_animation_finished)
	else:
		# Ledge fall safeguard
		_execute_true_launch()

func exit() -> void:
	if player.animator.anim_player.animation_finished.is_connected(_on_launch_animation_finished):
		player.animator.anim_player.animation_finished.disconnect(_on_launch_animation_finished)

func _on_launch_animation_finished(anim_name: String) -> void:
	if anim_name in ["jump_launch", "run_jump_launch"]:
		_execute_true_launch()

func _execute_true_launch() -> void:
	is_launching = false
	
	# Blast off!
	player.velocity.y = player.JUMP_VELOCITY 
	
	# Smoothly drop loose into your full physics ragdoll setup mid-air
	player.ragdoll.set_ragdoll_state(player.ragdoll.RagdollState.FULL_BODY)
	player.animator.play("jump")

func physics_update(delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	
	# --- AIR PHYSICS BREAK DURING WIND-UP ---
	if is_launching:
		# While winding up on the ground, still let them look in the direction they want to launch!
		if direction != 0:
			player.facing = -1 if direction < 0 else 1
			player.sprite_pivot.scale.x = player.facing
		return # ABSOLUTELY STOP the rest of the air code from processing until we clear the ground

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

	# --- ANIMATION & RAGDOLL CONTEXT LOGIC ---
	if player.velocity.y >= 0:
		player.animator.play("fall")
		player.ragdoll.set_ragdoll_state(player.ragdoll.RagdollState.FULL_BODY)

	# Jump Buffering & Double Jump
	if player.jump_buffer_timer > 0:
		if player.is_submerged:
			player.jump_buffer_timer = 0
			player.velocity.y = player.water_swim_velocity
			player.animator.play("jump") 
			player.ragdoll.set_ragdoll_state(player.ragdoll.RagdollState.FULL_BODY)
		elif player.can_double_jump:
			player.jump_buffer_timer = 0
			player.can_double_jump = false
			player.velocity.y = player.DOUBLE_JUMP_VELOCITY
			player.animator.play("double_jump", 0.0) 
			player.ragdoll.set_ragdoll_state(player.ragdoll.RagdollState.FULL_BODY)

	# Dash Transition
	if Input.is_action_just_pressed("ui_dash") and not player.is_submerged:
		state_machine.transition_to("dash")
		return

	# Ground Transition
	if player.is_on_floor() and player.velocity.y >= 0:
		state_machine.transition_to("ground")
		return
