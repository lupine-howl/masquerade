extends PlayerState

const LOCO_BLEND := 1.0

var _landing: bool = false
var _landing_blend_started: bool = false
var _run_starting: bool = false
var _was_moving: bool = false
var _current_anim: String = ""

func enter() -> void:
	_landing = false
	_landing_blend_started = false
	_run_starting = false
	_was_moving = false
	_current_anim = ""

	if _entered_from_air() and player.animator.has_animation("jump_land"):
		_landing = true
		player.velocity.x = 0.0
		_play_anim("jump_land", LOCO_BLEND)
	elif not _try_start_run():
		_play_anim("idle", LOCO_BLEND)

func exit() -> void:
	_landing = false
	_landing_blend_started = false
	_run_starting = false
	_current_anim = ""

func physics_update(delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	var y_dir := Input.get_axis("ui_up", "ui_down")

	if _landing:
		_update_landing_transition()
		player.velocity.x = move_toward(player.velocity.x, 0.0, player.SPEED * 8.0 * delta)
		if not player.is_on_floor() and player.velocity.y >= 0:
			state_machine.transition_to("air")
		return

	if _run_starting:
		_update_run_start_transition()
	else:
		_update_locomotion_animation(direction, y_dir)

	if direction != 0:
		var new_facing = -1 if direction < 0 else 1
		if new_facing != player.facing:
			player.facing = new_facing
			player.sprite_pivot.scale.x = player.facing
			for child in get_tree().get_nodes_in_group("flip_on_facing_change"):
				child.flip_h = (new_facing == -1)

	var current_target_speed := player.SPEED
	if player.is_submerged:
		current_target_speed *= player.water_speed_multiplier
	var horiz_gravity := player.get_gravity().x

	if direction != 0:
		var adaptive_target_speed: float = direction * current_target_speed + (horiz_gravity * 0.25)
		player.velocity.x = move_toward(player.velocity.x, adaptive_target_speed, player.SPEED * 8 * delta)
	else:
		if player.is_on_floor():
			horiz_gravity *= player.grounded_horizontal_current_dampening
		player.velocity.x = move_toward(player.velocity.x, horiz_gravity * 0.5, current_target_speed * 8 * delta)

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

func _update_landing_transition() -> void:
	if String(player.animator.current_animation) != "jump_land":
		_landing = false
		_landing_blend_started = false
		return

	var animation: Animation = player.animator.get_animation("jump_land")
	if not animation:
		_landing = false
		_landing_blend_started = false
		return

	if not _landing_blend_started and _should_crossfade_out("jump_land"):
		_landing_blend_started = true
		if not _try_start_run():
			_play_anim("idle", LOCO_BLEND)

	if player.animator.current_animation_position >= animation.length - 0.02:
		_landing = false
		_landing_blend_started = false

func _update_run_start_transition() -> void:
	if String(player.animator.current_animation) != "run_start":
		_run_starting = false
		return
	if not _should_crossfade_out("run_start"):
		return
	_run_starting = false
	if Input.get_axis("ui_left", "ui_right") != 0:
		_was_moving = true
		_play_anim("run", LOCO_BLEND)
	else:
		_was_moving = false
		_play_anim("idle", LOCO_BLEND)

func _should_crossfade_out(anim_name: String) -> bool:
	var animation: Animation = player.animator.get_animation(anim_name)
	if not animation:
		return true
	var blend_window := minf(LOCO_BLEND, maxf(animation.length * 0.35, 0.05))
	return player.animator.current_animation_position >= animation.length - blend_window

func _update_locomotion_animation(direction: float, y_dir: float) -> void:
	if direction != 0:
		if not _was_moving and player.animator.has_animation("run_start"):
			_run_starting = true
			_was_moving = true
			_play_anim("run_start", LOCO_BLEND)
		else:
			_play_anim("run", LOCO_BLEND)
			_was_moving = true
	elif y_dir > 0:
		_play_anim("hanging")
		_was_moving = false
	else:
		_play_anim("idle", LOCO_BLEND)
		_was_moving = false

func _try_start_run() -> bool:
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction == 0:
		return false
	if not _was_moving and player.animator.has_animation("run_start"):
		_run_starting = true
		_was_moving = true
		_play_anim("run_start", LOCO_BLEND)
		return true
	_play_anim("run", LOCO_BLEND)
	_was_moving = true
	return true

func _play_anim(anim_name: String, blend: float = -1.0) -> void:
	if anim_name == _current_anim and String(player.animator.current_animation) == anim_name:
		return
	_current_anim = anim_name
	if blend < 0.0:
		player.animator.play(anim_name)
	else:
		player.animator.play(anim_name, blend)

func _entered_from_air() -> bool:
	if not state_machine.previous_state:
		return false
	return state_machine.previous_state.name.to_lower() == "air"
