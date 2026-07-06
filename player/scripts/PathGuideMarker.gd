class_name PathGuideMarker
extends Node2D

enum Role {
	GUIDE_ONLY,
	DRIVE_BODY,
}

signal selected(guide: PathGuideMarker)
signal drag_ended(guide: PathGuideMarker)

@export var anchor: PathAnchor
@export var role: Role = Role.GUIDE_ONLY
@export var is_dev_mode: bool = true
@export var pick_radius: float = 20.0
@export var guide_color: Color = Color(1.0, 0.55, 0.1, 0.85)

var _player: Player
var _dragging := false
var _drag_offset := Vector2.ZERO

func _ready() -> void:
	add_to_group("pose_path_guides")
	_player = _find_player()
	set_process_unhandled_input(is_dev_mode)
	drag_ended.connect(_on_drag_ended)

func _find_player() -> Player:
	var node: Node = self
	while node:
		if node is Player:
			return node as Player
		node = node.get_parent()
	return null

func is_posing() -> bool:
	return _player != null and _player.is_posing

func should_show_gizmo() -> bool:
	return is_dev_mode and is_posing()

func get_climb_offset(facing: int) -> Vector2:
	return Vector2(position.x * facing, position.y)

## Authoring preview only — do not use for gameplay body placement.
func get_body_global_position() -> Vector2:
	if anchor:
		return anchor.global_position + position
	return global_position

static func gather_under(node: Node) -> Array[PathGuideMarker]:
	var guides: Array[PathGuideMarker] = []
	for child in node.get_tree().get_nodes_in_group("pose_path_guides"):
		if child is PathGuideMarker and node.is_ancestor_of(child):
			guides.append(child)
	return guides

func _process(_delta: float) -> void:
	visible = should_show_gizmo()
	queue_redraw()

func _draw() -> void:
	if not should_show_gizmo():
		return
	draw_circle(Vector2.ZERO, pick_radius, guide_color)
	if anchor and anchor.is_inside_tree():
		draw_line(Vector2.ZERO, -position, guide_color.darkened(0.25), 2.0)

func _unhandled_input(event: InputEvent) -> void:
	if not should_show_gizmo():
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed and _is_mouse_over():
			_sync_anchor_for_authoring()
			_dragging = true
			_drag_offset = global_position - get_global_mouse_position()
			selected.emit(self)
			get_viewport().set_input_as_handled()
		elif not mouse_event.pressed and _dragging:
			_dragging = false
			drag_ended.emit(self)
	elif event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() + _drag_offset
		if anchor:
			position = global_position - anchor.global_position
		get_viewport().set_input_as_handled()

func _is_mouse_over() -> bool:
	return global_position.distance_to(get_global_mouse_position()) <= pick_radius

func _on_drag_ended() -> void:
	if not is_posing() or _player == null:
		return
	var pose_controller := _player.sprite_pivot.get_node_or_null("PoseController") as PoseController
	if pose_controller and pose_controller.pose_hud:
		pose_controller.pose_hud.key_path_guide(self)

func _sync_anchor_for_authoring() -> void:
	if anchor and _player:
		anchor.prepare_authoring_at(_player.global_position)
