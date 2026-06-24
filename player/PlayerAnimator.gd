extends Node
class_name PlayerAnimator

@export var anim_player: AnimationPlayer

# This single function replaces your entire AnimationTree!
func play(anim_name: String, blend_time: float = 0.0, custom_speed: float = 1.0) -> void:
	if anim_player and anim_player.has_animation(anim_name):
		anim_player.play(anim_name, blend_time)
		anim_player.speed_scale = custom_speed
