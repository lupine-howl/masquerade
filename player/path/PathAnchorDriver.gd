class_name PathAnchorDriver
extends RefCounted

var _origin := Vector2.ZERO
var _guide: PathGuideMarker
var _active := false

func is_active() -> bool:
	return _active

func get_origin() -> Vector2:
	return _origin

func get_guide() -> PathGuideMarker:
	return _guide if _active else null

func begin(guide: PathGuideMarker, player: Player) -> void:
	end()
	_guide = guide
	if _guide and _guide.anchor:
		_origin = _guide.anchor.global_position
		_guide.anchor.lock_at(_origin)
	elif player:
		_origin = player.global_position
	else:
		_origin = Vector2.ZERO
	_active = _guide != null

func end() -> void:
	if not _active:
		return
	if _guide and _guide.anchor:
		_guide.anchor.release_lock()
	_active = false
	_guide = null

func sync_body(player: Player) -> void:
	if not _active or _guide == null or player == null:
		return
	player.global_position = _origin + _guide.get_climb_offset(player.facing)
