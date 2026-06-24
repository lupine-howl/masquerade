extends Node
class_name PlayerAnimator

@export var anim_player: AnimationPlayer

# Play an animation with optional blend and speed
func play(anim_name: String, blend_time: float = 0.0, custom_speed: float = 1.0) -> void:
	if anim_player and anim_player.has_animation(anim_name):
		anim_player.speed_scale = custom_speed
		anim_player.play(anim_name, blend_time)

func stop() -> void:
	if anim_player:
		anim_player.stop()
		anim_player.speed_scale = 1.0
