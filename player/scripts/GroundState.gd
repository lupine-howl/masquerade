extends PlayerState

const ANIM_BLENDS := {
	"idle": 0.5,
	"run": 0.35,
	"hanging": 0.2,
	"jump_land": 0.2,
}
const LAND_POSE_TIME := 0.15

var _landing: bool = false
var _land_time: float = 0.0

func enter() -> void:
	_landing = false
	_land_time = 0.0
	if _entered_from_air() and player.animator.has_animation("jump_land"):
		_landing = true
		player.velocity.x = 0.0
		_play("jump_land")
	elif Input.get_axis("ui_left", "ui_right") != 0:
		_play("run")
	else:
		_play("idle")

func exit() -> void:
	_landing = false

func physics_update(delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	var y_dir := Input.get_axis("ui_up", "ui_down")

	if _landing:
		player.velocity.x = move_toward(player.velocity.x, 0.0, player.SPEED * 8.0 * delta)
		if not player.is_on_floor() and player.velocity.y >= 0:
			state_machine.transition_to("air")
			return
		_land_time += delta
		if _land_time >= LAND_POSE_TIME:
			_finish_landing()
		return

	if direction != 0:
		var new_facing := -1 if direction < 0 else 1
		if new_facing != player.facing:
			player.facing = new_facing
			player.sprite_pivot.scale.x = player.facing
			for child in get_tree().get_nodes_in_group("flip_on_facing_change"):
				child.flip_h = (new_facing == -1)

	if direction != 0:
		_play("run")
	elif y_dir > 0:
		_play("hanging")
	else:
		_play("idle")

	var target_speed := player.SPEED * (player.water_speed_multiplier if player.is_submerged else 1.0)
	var horiz_gravity := player.get_gravity().x

	if direction != 0:
		player.velocity.x = move_toward(
			player.velocity.x,
			direction * target_speed + horiz_gravity * 0.25,
			player.SPEED * 8.0 * delta
		)
	else:
		if player.is_on_floor():
			horiz_gravity *= player.grounded_horizontal_current_dampening
		player.velocity.x = move_toward(player.velocity.x, horiz_gravity * 0.5, target_speed * 8.0 * delta)

	if Input.is_action_just_pressed("ui_dash") and not player.is_submerged:
		state_machine.transition_to("dash")
	elif player.attack_timer > 0.0 and y_dir > 0 and not player.is_submerged:
		state_machine.transition_to("roll")
	elif player.jump_buffer_timer > 0:
		player.jump_buffer_timer = 0
		player.velocity.y = player.water_swim_velocity if player.is_submerged else player.JUMP_VELOCITY
		state_machine.transition_to("air")
	elif not player.is_on_floor() and player.velocity.y >= 0:
		state_machine.transition_to("air")

func _finish_landing() -> void:
	_landing = false
	if Input.get_axis("ui_left", "ui_right") != 0:
		_play("run")
	else:
		_play("idle")

func _play(anim_name: String) -> void:
	if String(player.animator.current_animation) == anim_name and player.animator.is_playing():
		return
	var blend: float = ANIM_BLENDS.get(anim_name, -1.0)
	if blend < 0.0:
		player.animator.play(anim_name)
	else:
		player.animator.play(anim_name, blend)

func _entered_from_air() -> bool:
	return (
		state_machine.previous_state != null
		and state_machine.previous_state.name.to_lower() == "air"
	)
