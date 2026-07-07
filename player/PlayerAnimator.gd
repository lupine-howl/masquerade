extends AnimationPlayer
class_name PlayerAnimator

signal path_body_finished(anim_name: String)

var current_anim: String

var _player: Player
var _path_drive_active := false
var _path_anchor_driver := PathAnchorDriver.new()
var _path_drive_anim := ""
var _disabled_collision_for_path := false

func _ready() -> void:
	_player = get_parent() as Player
	animation_started.connect(_on_animation_started)
	animation_finished.connect(_on_animation_finished)

func is_path_body_driving() -> bool:
	return _path_drive_active

func physics_update_path_body() -> void:
	if not _path_drive_active or _player == null:
		return
	_player.velocity = Vector2.ZERO
	sync_path_body_position()

func sync_path_body_position() -> void:
	_path_anchor_driver.sync_body(_player)

func end_path_body_drive() -> void:
	if not _path_drive_active:
		return
	_path_drive_active = false
	_path_anchor_driver.end()
	if _disabled_collision_for_path and _player and _player.master_collision_shape:
		_player.master_collision_shape.disabled = false
		_disabled_collision_for_path = false
	if _player:
		_player.armature.position = Vector2.ZERO
	_path_drive_anim = ""

func _on_animation_started(anim_name: StringName) -> void:
	var anim_name_str := String(anim_name)
	speed_scale = read_speed_scale_key(anim_name_str)
	_try_begin_path_body_drive(anim_name_str)

func _on_animation_finished(anim_name: StringName) -> void:
	if not _path_drive_active or String(anim_name) != _path_drive_anim:
		return
	sync_path_body_position()
	path_body_finished.emit(_path_drive_anim)

func _try_begin_path_body_drive(anim_name: String) -> void:
	if _player == null or _player.is_posing:
		return
	if not animation_has_path_guide_keys(self, anim_name):
		end_path_body_drive()
		return
	var guide := PathGuideMarker.get_drive_body_guide(_player)
	if guide == null or guide.role != PathGuideMarker.Role.DRIVE_BODY:
		end_path_body_drive()
		return
	if _path_drive_active and _path_drive_anim == anim_name:
		return

	end_path_body_drive()

	_path_drive_active = true
	_path_drive_anim = anim_name

	_player.velocity = Vector2.ZERO
	_player.armature.position = Vector2.ZERO

	_disabled_collision_for_path = false
	if _player.master_collision_shape and not _player.master_collision_shape.disabled:
		_player.master_collision_shape.disabled = true
		_disabled_collision_for_path = true

	seek(0.0, true)
	_path_anchor_driver.begin(guide, _player)
	sync_path_body_position()

static func animation_has_path_guide_keys(animator: AnimationPlayer, anim_name: String) -> bool:
	if not animator.has_animation(anim_name):
		return false
	var animation := animator.get_animation(anim_name)
	for i in animation.get_track_count():
		var path := str(animation.track_get_path(i))
		if path.begins_with("PathAnchors/") and path.ends_with(":position"):
			if animation.track_get_key_count(i) > 0:
				return true
	return false

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
