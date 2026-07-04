extends AnimationPlayer
class_name PlayerAnimator

var current_anim: String

func _ready() -> void:
	animation_started.connect(_on_animation_started)

func _on_animation_started(anim_name: StringName) -> void:
	speed_scale = read_speed_scale_key(String(anim_name))

func read_speed_scale_key(anim_name: String) -> float:
	if not has_animation(anim_name):
		return 1.0
	var animation := get_animation(anim_name)
	var track_idx := _find_speed_scale_track(animation)
	if track_idx == -1:
		return 1.0
	var key_idx := animation.track_find_key(track_idx, 0.0, Animation.FIND_MODE_NEAREST)
	if key_idx == -1 or abs(animation.track_get_key_time(track_idx, key_idx)) > 0.01:
		return 1.0
	return float(animation.track_get_key_value(track_idx, key_idx))

func _find_speed_scale_track(animation: Animation) -> int:
	var root := get_node(root_node)
	var expected := str(root.get_path_to(self)) + ":speed_scale"
	var track_idx := animation.find_track(expected, Animation.TYPE_VALUE)
	if track_idx != -1:
		return track_idx
	for i in animation.get_track_count():
		if str(animation.track_get_path(i)).ends_with(":speed_scale"):
			return i
	return -1
