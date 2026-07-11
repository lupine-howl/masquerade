class_name TileAtlasPicker
extends Control

## Contiguous atlas tile picker with rectangular drag selection (Godot editor style).

signal selection_changed(pattern: TileMapPattern, source_id: int, selection_rect: Rect2i)

const VISIBLE_ATLAS_ROWS := 3
const ROW_VIEW_HEIGHT := 44

var _atlas: TileSetAtlasSource
var _source_id: int = -1
var _zoom: float = 1.0

var _selection := Rect2i()
var _has_selection: bool = false
var _dragging: bool = false
var _drag_start := Vector2i.ZERO


func set_source(atlas: TileSetAtlasSource, source_id: int) -> void:
	_atlas = atlas
	_source_id = source_id
	_clear_selection()
	_update_layout()
	queue_redraw()


func clear_selection() -> void:
	_clear_selection()


func get_selection_rect() -> Rect2i:
	return _selection


func build_pattern() -> TileMapPattern:
	if _atlas == null or not _has_selection:
		return null
	var pattern := TileMapPattern.new()
	pattern.set_size(_selection.size)
	var placed := 0
	for y in _selection.size.y:
		for x in _selection.size.x:
			var atlas_coord := _selection.position + Vector2i(x, y)
			if _atlas.has_tile(atlas_coord):
				pattern.set_cell(Vector2i(x, y), _source_id, atlas_coord)
				placed += 1
	return pattern if placed > 0 else null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	focus_mode = Control.FOCUS_NONE


func _clear_selection() -> void:
	_has_selection = false
	_selection = Rect2i()
	_dragging = false
	queue_redraw()


func _update_layout() -> void:
	if _atlas == null or _atlas.texture == null:
		custom_minimum_size = Vector2.ZERO
		_zoom = 1.0
		return

	var cell := _cell_pixel_size()
	if cell.y <= 0:
		cell.y = 16
	var view_height := ROW_VIEW_HEIGHT * VISIBLE_ATLAS_ROWS
	_zoom = float(view_height) / float(VISIBLE_ATLAS_ROWS * cell.y)
	custom_minimum_size = _atlas.texture.get_size() * _zoom


func _cell_pixel_size() -> Vector2i:
	if _atlas == null:
		return Vector2i.ZERO
	return _atlas.texture_region_size + _atlas.separation


func _draw() -> void:
	if _atlas == null or _atlas.texture == null:
		return

	draw_texture_rect(_atlas.texture, Rect2(Vector2.ZERO, custom_minimum_size), false)
	if _has_selection:
		_draw_selection()


func _draw_selection() -> void:
	var cell := _cell_pixel_size()
	var top_left := Vector2(_atlas.margins) * _zoom + Vector2(_selection.position) * Vector2(cell) * _zoom
	var size := Vector2(_selection.size) * Vector2(cell) * _zoom
	var rect := Rect2(top_left, size)
	draw_rect(rect, Color(1.0, 0.9, 0.2, 0.25), true)
	draw_rect(rect, Color(1.0, 0.85, 0.1, 0.95), false, 2.0)


func _gui_input(event: InputEvent) -> void:
	if _atlas == null or _atlas.texture == null:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var atlas_coord := _local_to_atlas_coord(mb.position)
		if mb.pressed:
			_dragging = true
			_drag_start = atlas_coord
			_set_selection_rect(atlas_coord, atlas_coord)
			accept_event()
		else:
			_dragging = false
			_emit_selection()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var atlas_coord := _local_to_atlas_coord((event as InputEventMouseMotion).position)
		_set_selection_rect(_drag_start, atlas_coord)
		accept_event()


func _local_to_atlas_coord(local: Vector2) -> Vector2i:
	var cell := _cell_pixel_size()
	var scaled_cell := Vector2(cell) * _zoom
	var scaled_margins := Vector2(_atlas.margins) * _zoom
	var rel := local - scaled_margins
	return Vector2i(
		floori(rel.x / scaled_cell.x),
		floori(rel.y / scaled_cell.y)
	)


func _set_selection_rect(from: Vector2i, to: Vector2i) -> void:
	var min_corner := Vector2i(mini(from.x, to.x), mini(from.y, to.y))
	var max_corner := Vector2i(maxi(from.x, to.x), maxi(from.y, to.y))
	_selection = Rect2i(min_corner, max_corner - min_corner + Vector2i.ONE)
	_has_selection = true
	queue_redraw()


func _emit_selection() -> void:
	_normalize_single_tile_selection()
	var pattern := build_pattern()
	if pattern == null:
		_has_selection = false
		queue_redraw()
		return
	selection_changed.emit(pattern, _source_id, _selection)


func _normalize_single_tile_selection() -> void:
	if _atlas == null or _selection.size != Vector2i.ONE:
		return
	var origin := _atlas.get_tile_at_coords(_selection.position)
	if origin != Vector2i(-1, -1):
		_selection = Rect2i(origin, Vector2i.ONE)
