extends PlayerState

var timer: float = 0.0

func enter() -> void:
	# Snappy, instant animation trigger
	player.animator.play("roll", 0.0)
	
	timer = 0.25
	player.velocity.x = player.facing * player.ROLL_BOOST

func physics_update(delta: float) -> void:
	timer -= delta
	if timer <= 0:
		if player.is_on_floor(): state_machine.transition_to("ground")
		else: state_machine.transition_to("air")
