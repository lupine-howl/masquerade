class_name PathGuideMarker
extends Node2D

enum Role {
	GUIDE_ONLY,
	DRIVE_BODY,
}

signal selected(guide: PathGuideMarker)
signal drag_ended(guide: PathGuideMarker)

@export var anchor: PathAnchor
@export var follow: Node2D
@export var player: Player
@export var role: Role = Role.GUIDE_ONLY
@export var is_dev_mode: bool = true
@export var pick_radius: float = 20.0
@export var guide_color: Color = Color(1.0, 0.55, 0.1, 0.85)
@export var show_capsule_halo: bool = true
@export var halo_fill_color: Color = Color(1.0, 0.55, 0.1, 0.12)
@export var halo_outline_color: Color = Color(1.0, 0.55, 0.1, 0.55)

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
	if not is_dev_mode or not is_posing():
		return false
	return _is_player_drive_authoring_enabled()

func _is_player_drive_authoring_enabled() -> bool:
	if _player == null:
		return false
	var pose_controller := _player.sprite_pivot.get_node_or_null("PoseController") as PoseController
	if pose_controller == null or pose_controller.pose_hud == null or pose_controller.pose_hud.timeline == null:
		return false
	var anim_name := pose_controller.pose_hud.get_current_animation()
	if anim_name == "":
		return false
	return pose_controller.pose_hud.timeline.is_path_body_drive_authoring_enabled(anim_name)

func get_climb_offset(facing: int) -> Vector2:
	return Vector2(position.x * facing, position.y)

static func get_drive_body_guide(player: Player) -> PathGuideMarker:
	for guide in gather_under(player):
		if guide.role == Role.DRIVE_BODY:
			return guide
	return null

static func get_path_compensation_offset(player: Player) -> Vector2:
	var guide := get_drive_body_guide(player)
	if guide == null:
		return Vector2.ZERO
	return guide.get_climb_offset(player.facing)

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
	
func _physics_process(_delta: float) -> void:
	if not player or not player.is_posing or not should_show_gizmo():
		return
	global_position = follow.global_position

func _draw() -> void:
	if not should_show_gizmo():
		return
	if show_capsule_halo and _player:
		_draw_capsule_halo(
			_player.get_body_capsule_radius(),
			_player.get_body_capsule_total_height(),
			halo_fill_color,
			halo_outline_color
		)
	draw_circle(Vector2.ZERO, pick_radius, guide_color)
	if anchor and anchor.is_inside_tree():
		draw_line(Vector2.ZERO, -position, guide_color.darkened(0.25), 2.0)

func _draw_capsule_halo(radius: float, total_height: float, fill: Color, outline: Color) -> void:
	var half := total_height * 0.5
	var top_center := Vector2(0.0, -half + radius)
	var bottom_center := Vector2(0.0, half - radius)
	var cylinder_height := maxf(0.0, total_height - radius * 2.0)
	var cyl_half := cylinder_height * 0.5
	var segments := 24
	draw_circle(top_center, radius, fill)
	draw_circle(bottom_center, radius, fill)
	if cylinder_height > 0.0:
		draw_rect(Rect2(Vector2(-radius, -cyl_half), Vector2(radius * 2.0, cylinder_height)), fill)
	draw_arc(top_center, radius, PI, TAU, segments, outline, 2.0)
	draw_arc(bottom_center, radius, 0.0, PI, segments, outline, 2.0)
	if cylinder_height > 0.0:
		draw_line(top_center + Vector2(-radius, 0.0), bottom_center + Vector2(-radius, 0.0), outline, 2.0)
		draw_line(top_center + Vector2(radius, 0.0), bottom_center + Vector2(radius, 0.0), outline, 2.0)

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
		var new_global := get_global_mouse_position() + _drag_offset
		if anchor:
			position = new_global - anchor.global_position
		else:
			global_position = new_global
		get_viewport().set_input_as_handled()

func _is_mouse_over() -> bool:
	var mouse_local := to_local(get_global_mouse_position())
	if show_capsule_halo and _player:
		return _point_in_capsule(
			mouse_local,
			_player.get_body_capsule_radius(),
			_player.get_body_capsule_total_height()
		)
	return mouse_local.length() <= pick_radius

func _point_in_capsule(point: Vector2, radius: float, total_height: float) -> bool:
	var half := total_height * 0.5
	if absf(point.x) > radius:
		return false
	var top_center_y := -half + radius
	var bottom_center_y := half - radius
	if point.y >= top_center_y and point.y <= bottom_center_y:
		return true
	if point.y < top_center_y:
		return point.distance_squared_to(Vector2(0.0, top_center_y)) <= radius * radius
	return point.distance_squared_to(Vector2(0.0, bottom_center_y)) <= radius * radius

func _on_drag_ended() -> void:
	if not is_posing() or _player == null:
		return
	var pose_controller := _player.sprite_pivot.get_node_or_null("PoseController") as PoseController
	if pose_controller and pose_controller.pose_hud:
		pose_controller.pose_hud.key_path_guide(self)

func _sync_anchor_for_authoring() -> void:
	if anchor and _player:
		anchor.prepare_authoring_at(_player.global_position)
