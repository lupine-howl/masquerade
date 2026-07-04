extends PlayerState

# Track whether the character has successfully left the ground yet
var is_launching: bool = false

func enter() -> void:
	is_launching = true

	if player.is_on_floor():
		var is_running: bool = abs(player.velocity.x) > (player.SPEED * 0.2)
		player.velocity.x *= 0.4
		player.velocity.y = 0

		if is_running and player.animator.has_animation("run_jump_launch"):
			player.animator.play("run_jump_launch")
		else:
			player.animator.play("jump_launch")

		if not player.animator.animation_finished.is_connected(_on_launch_animation_finished):
			player.animator.animation_finished.connect(_on_launch_animation_finished)
	else:
		_execute_true_launch()

func exit() -> void:
	if player.animator.animation_finished.is_connected(_on_launch_animation_finished):
		player.animator.animation_finished.disconnect(_on_launch_animation_finished)

func _on_launch_animation_finished(anim_name: String) -> void:
	if anim_name in ["jump_launch", "run_jump_launch"]:
		_execute_true_launch()

func _execute_true_launch() -> void:
	is_launching = false
	player.velocity.y = player.JUMP_VELOCITY
	player.animator.play("jump")

func physics_update(delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")

	if is_launching:
		if direction != 0:
			player.facing = -1 if direction < 0 else 1
			player.sprite_pivot.scale.x = player.facing
		return

	var current_target_speed := player.SPEED
	if player.is_submerged:
		current_target_speed *= player.water_speed_multiplier
	var horiz_gravity := player.get_gravity().x

	if direction != 0:
		var adaptive_target_speed: float = direction * current_target_speed + (horiz_gravity * 0.25)
		player.velocity.x = move_toward(player.velocity.x, adaptive_target_speed, player.SPEED * 8 * delta)

		var new_facing = -1 if direction < 0 else 1
		if new_facing != player.facing:
			player.facing = new_facing
			player.sprite_pivot.scale.x = player.facing
			for child in get_tree().get_nodes_in_group("flip_on_facing_change"):
				child.flip_h = (new_facing == -1)
	else:
		player.velocity.x = move_toward(player.velocity.x, horiz_gravity * 0.5, current_target_speed * 8 * delta)

	if player.velocity.y >= 0:
		var playing := String(player.animator.current_animation)
		if playing != "fall":
			player.animator.play("fall", 0.15)

	if player.jump_buffer_timer > 0:
		if player.is_submerged:
			player.jump_buffer_timer = 0
			player.velocity.y = player.water_swim_velocity
			player.animator.play("jump")
		elif player.can_double_jump:
			player.jump_buffer_timer = 0
			player.can_double_jump = false
			player.velocity.y = player.DOUBLE_JUMP_VELOCITY
			player.animator.play("double_jump", 0.0)

	if Input.is_action_just_pressed("ui_dash") and not player.is_submerged:
		state_machine.transition_to("dash")
		return

	if player.is_on_floor() and player.velocity.y >= 0:
		state_machine.transition_to("ground")
		return
