extends PlayerState

var timer: float = 0.0

func enter() -> void:
	timer = 0.2 # 0.2 seconds of stun
	player.is_invincible = true
	
func physics_update(delta: float) -> void:
	timer -= delta
	
	# Apply gravity and slide while knocked back
	player._apply_gravity(delta)
	player.move_and_slide()
	
	if timer <= 0:
		state_machine.transition_to("ground")
