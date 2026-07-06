class_name PathAnchor
extends Node2D

## World-fixed origin for a PathGuideMarker trajectory. Lock at climb start; release after.
var _locked := false

func lock_at(world_position: Vector2) -> void:
	global_position = world_position
	top_level = true
	_locked = true

func release_lock() -> void:
	if not _locked:
		return
	top_level = false
	_locked = false

func prepare_authoring_at(world_position: Vector2) -> void:
	release_lock()
	global_position = world_position

func is_locked() -> bool:
	return _locked
