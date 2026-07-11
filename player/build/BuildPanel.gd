@tool
class_name BuildPanel
extends PanelContainer

## Level-build panel: layer tabs, tileset sources, full-width tile strip.
## Painting targets TileMapLayer nodes in the active level by name.

signal tile_selected(tilemap: String, source_id: int, atlas_coords: Vector2i)

const TILEMAPS: Array[Dictionary] = [
	{"name": "Terrain", "tileset": "res://resources/tilesets/tileset_terrain.tres"},
	{"name": "Hazards", "tileset": "res://resources/tilesets/tileset_enemies.tres"},
	{"name": "Controls", "tileset": "res://resources/tilesets/tileset_controls.tres"},
	{"name": "Water", "tileset": "res://resources/tilesets/tileset_water.tres"},
]

const TILE_BUTTON_SIZE := 40
const TILE_VISIBLE_ROWS := 4

var _tab_strip: VBoxContainer
var _source_row: HFlowContainer
var _tile_grid: GridContainer
var _header_label: Label
var _selected_label: Label

var _tab_buttons: Array[Button] = []
var _source_buttons: Array[Button] = []
var _tile_buttons: Array[Button] = []

var _current_tilemap_index: int = -1
var _current_source_id: int = -1
var _selected_tile_button: Button = null

var paint_enabled: bool = false
var _has_selection: bool = false
var _paint_source_id: int = -1
var _paint_coords: Vector2i = Vector2i.ZERO

var _brush: Node2D = null
var _brush_layer: TileMapLayer = null
var _hover_coords: Vector2i = Vector2i.ZERO
var _brush_visible: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2.ZERO
	_build_ui()
	_populate_tilemap_tabs()
	if not TILEMAPS.is_empty():
		_select_tilemap(0)


func _build_ui() -> void:
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color(0, 0, 0, 0)
	add_theme_stylebox_override("panel", transparent)

	var content_row := HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 0)
	content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(content_row)

	var tab_strip_panel := PanelContainer.new()
	PoseTabStyles.apply_left_tab_strip(tab_strip_panel)
	tab_strip_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content_row.add_child(tab_strip_panel)

	_tab_strip = VBoxContainer.new()
	_tab_strip.add_theme_constant_override("separation", 2)
	PoseTabStyles.configure_strip_container(_tab_strip)
	tab_strip_panel.add_child(_tab_strip)

	var main_panel := PanelContainer.new()
	main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	PoseTabStyles.apply_content_panel(main_panel, true)
	content_row.add_child(main_panel)

	var main_col := VBoxContainer.new()
	main_col.add_theme_constant_override("separation", 3)
	main_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_panel.add_child(main_col)

	_header_label = Label.new()
	_header_label.add_theme_font_size_override("font_size", PoseTabStyles.PANEL_FONT_SIZE)
	_header_label.text = "Build"
	main_col.add_child(_header_label)

	var source_caption := Label.new()
	source_caption.add_theme_font_size_override("font_size", PoseTabStyles.CAPTION_FONT_SIZE)
	source_caption.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	source_caption.text = "Tilesets"
	main_col.add_child(source_caption)

	var source_scroll := ScrollContainer.new()
	source_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	source_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	source_scroll.custom_minimum_size = Vector2(0, 28)
	source_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_col.add_child(source_scroll)

	_source_row = HFlowContainer.new()
	_source_row.add_theme_constant_override("h_separation", 3)
	_source_row.add_theme_constant_override("v_separation", 3)
	_source_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_scroll.add_child(_source_row)

	var tiles_caption := Label.new()
	tiles_caption.add_theme_font_size_override("font_size", PoseTabStyles.CAPTION_FONT_SIZE)
	tiles_caption.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	tiles_caption.text = "Tiles"
	main_col.add_child(tiles_caption)

	var tile_scroll := ScrollContainer.new()
	tile_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tile_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tile_scroll.custom_minimum_size = Vector2(0, TILE_VISIBLE_ROWS * (TILE_BUTTON_SIZE + 4))
	tile_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	main_col.add_child(tile_scroll)

	_tile_grid = GridContainer.new()
	_tile_grid.add_theme_constant_override("h_separation", 4)
	_tile_grid.add_theme_constant_override("v_separation", 4)
	_tile_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_scroll.add_child(_tile_grid)

	_selected_label = Label.new()
	_selected_label.add_theme_font_size_override("font_size", PoseTabStyles.CAPTION_FONT_SIZE)
	_selected_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	_selected_label.text = "No tile selected"
	main_col.add_child(_selected_label)


func _populate_tilemap_tabs() -> void:
	_clear_children(_tab_strip)
	_tab_buttons.clear()
	for i in TILEMAPS.size():
		var entry: Dictionary = TILEMAPS[i]
		var btn := PoseTabStyles.make_tab_button(String(entry.name), "Tilemap: %s" % entry.name)
		PoseTabStyles.apply_tab_button(btn, false, false)
		btn.pressed.connect(_select_tilemap.bind(i))
		_tab_strip.add_child(btn)
		_tab_buttons.append(btn)


func _select_tilemap(index: int) -> void:
	if index < 0 or index >= TILEMAPS.size():
		return
	_current_tilemap_index = index
	for i in _tab_buttons.size():
		PoseTabStyles.apply_tab_button(_tab_buttons[i], i == index, false)

	var entry: Dictionary = TILEMAPS[index]
	_header_label.text = "Build — %s" % entry.name
	var tileset := _load_tileset(String(entry.tileset))
	_populate_sources(tileset)


func _populate_sources(tileset: TileSet) -> void:
	_clear_children(_source_row)
	_source_buttons.clear()
	_clear_children(_tile_grid)
	_tile_buttons.clear()
	_selected_tile_button = null
	_selected_label.text = "No tile selected"

	if tileset == null:
		var missing := Label.new()
		missing.text = "(tileset not found)"
		missing.add_theme_font_size_override("font_size", PoseTabStyles.CAPTION_FONT_SIZE)
		_source_row.add_child(missing)
		return

	var first_source_id := -1
	for i in tileset.get_source_count():
		var source_id := tileset.get_source_id(i)
		var source := tileset.get_source(source_id)
		var full_label := _source_label(source, source_id)
		var btn := Button.new()
		btn.text = full_label.trim_prefix("tileset-")
		btn.tooltip_text = full_label
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", PoseTabStyles.CAPTION_FONT_SIZE)
		btn.toggle_mode = true
		btn.set_meta("source_id", source_id)
		btn.pressed.connect(_select_source.bind(tileset, source_id))
		_source_row.add_child(btn)
		_source_buttons.append(btn)
		if first_source_id == -1:
			first_source_id = source_id

	if first_source_id != -1:
		_select_source(tileset, first_source_id)


func _select_source(tileset: TileSet, source_id: int) -> void:
	_current_source_id = source_id
	for btn in _source_buttons:
		btn.set_pressed_no_signal(int(btn.get_meta("source_id", -1)) == source_id)
	var source := tileset.get_source(source_id)
	_populate_tiles(source, source_id)


func _populate_tiles(source: TileSetSource, source_id: int) -> void:
	_clear_children(_tile_grid)
	_tile_buttons.clear()
	_selected_tile_button = null

	var atlas := source as TileSetAtlasSource
	if atlas == null:
		var note := Label.new()
		note.text = "Scene-collection tileset (no atlas preview)"
		note.add_theme_font_size_override("font_size", PoseTabStyles.CAPTION_FONT_SIZE)
		_tile_grid.add_child(note)
		return

	for i in atlas.get_tiles_count():
		var coords := atlas.get_tile_id(i)
		var region := atlas.get_tile_texture_region(coords, 0)
		if region.size.x <= 0 or region.size.y <= 0:
			continue
		var tex := AtlasTexture.new()
		tex.atlas = atlas.texture
		tex.region = region
		var btn := _make_tile_button(tex)
		btn.pressed.connect(_on_tile_pressed.bind(btn, source_id, coords))
		_tile_grid.add_child(btn)
		_tile_buttons.append(btn)

	_update_tile_grid_columns()

	if _tile_buttons.is_empty():
		var empty := Label.new()
		empty.text = "(no tiles)"
		empty.add_theme_font_size_override("font_size", PoseTabStyles.CAPTION_FONT_SIZE)
		_tile_grid.add_child(empty)


func _update_tile_grid_columns() -> void:
	if _tile_grid == null:
		return
	var count := _tile_buttons.size()
	if count == 0:
		_tile_grid.columns = 1
		return
	_tile_grid.columns = maxi(1, ceili(float(count) / float(TILE_VISIBLE_ROWS)))


func _make_tile_button(tex: Texture2D) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(TILE_BUTTON_SIZE, TILE_BUTTON_SIZE)
	btn.focus_mode = Control.FOCUS_NONE
	btn.icon = tex
	btn.expand_icon = true
	btn.tooltip_text = "Click to select tile"
	_style_tile_button(btn, false)
	return btn


func _style_tile_button(btn: Button, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.9)
	style.set_content_margin_all(2)
	style.set_corner_radius_all(3)
	style.set_border_width_all(2)
	style.border_color = Color(0.35, 0.65, 0.95) if selected else Color(0.25, 0.25, 0.28)
	btn.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.border_color = Color(0.45, 0.75, 1.0)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", style)


func _on_tile_pressed(btn: Button, source_id: int, coords: Vector2i) -> void:
	if _selected_tile_button and is_instance_valid(_selected_tile_button):
		_style_tile_button(_selected_tile_button, false)
	_selected_tile_button = btn
	_style_tile_button(btn, true)
	_paint_source_id = source_id
	_paint_coords = coords
	_has_selection = true
	var tilemap_name := "?"
	if _current_tilemap_index >= 0:
		tilemap_name = String(TILEMAPS[_current_tilemap_index].name)
	_selected_label.text = "Selected: %s / src %d / (%d, %d)" % [
		tilemap_name, source_id, coords.x, coords.y
	]
	tile_selected.emit(tilemap_name, source_id, coords)


func _source_label(source: TileSetSource, source_id: int) -> String:
	var atlas := source as TileSetAtlasSource
	if atlas != null and atlas.texture != null:
		var path := atlas.texture.resource_path
		if path != "":
			return path.get_file().get_basename()
	return "Source %d" % source_id


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not paint_enabled:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_paint_at_mouse(false)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_paint_at_mouse(true)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_update_brush_hover()
		var mask := (event as InputEventMouseMotion).button_mask
		if mask & MOUSE_BUTTON_MASK_LEFT:
			_paint_at_mouse(false)
		elif mask & MOUSE_BUTTON_MASK_RIGHT:
			_paint_at_mouse(true)


func _paint_at_mouse(erase: bool) -> void:
	if not erase and not _has_selection:
		return
	if _current_tilemap_index < 0:
		return
	var layer := _find_target_layer(String(TILEMAPS[_current_tilemap_index].name))
	if layer == null:
		push_warning("BuildPanel: no TileMapLayer named '%s' in the current level." % TILEMAPS[_current_tilemap_index].name)
		return
	var world := layer.get_global_mouse_position()
	var coords := layer.local_to_map(layer.to_local(world))
	if erase:
		layer.erase_cell(coords)
		return
	if layer.tile_set == null or not layer.tile_set.has_source(_paint_source_id):
		push_warning("BuildPanel: layer '%s' uses a different tileset (no source %d)." % [layer.name, _paint_source_id])
		return
	layer.set_cell(coords, _paint_source_id, _paint_coords)


func _find_target_layer(layer_name: String) -> TileMapLayer:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var node := scene.find_child(layer_name, true, false)
	return node as TileMapLayer


func _update_brush_hover() -> void:
	if Engine.is_editor_hint() or not paint_enabled or _current_tilemap_index < 0:
		_set_brush_visible(false)
		return
	var layer := _find_target_layer(String(TILEMAPS[_current_tilemap_index].name))
	if layer == null:
		_set_brush_visible(false)
		return
	_ensure_brush(layer)
	var world := layer.get_global_mouse_position()
	_hover_coords = layer.local_to_map(layer.to_local(world))
	_set_brush_visible(true)
	_brush.queue_redraw()


func _ensure_brush(layer: TileMapLayer) -> void:
	if _brush != null and is_instance_valid(_brush) and _brush_layer == layer:
		return
	if _brush != null and is_instance_valid(_brush):
		_brush.queue_free()
	_brush = Node2D.new()
	_brush.z_index = 1000
	layer.add_child(_brush)
	_brush_layer = layer
	_brush.draw.connect(_on_brush_draw)


func _set_brush_visible(value: bool) -> void:
	_brush_visible = value
	if _brush != null and is_instance_valid(_brush):
		_brush.visible = value


func _on_brush_draw() -> void:
	if not _brush_visible or _brush_layer == null or not is_instance_valid(_brush_layer):
		return
	var ts := _brush_layer.tile_set
	var cell := Vector2(ts.tile_size) if ts else Vector2(16, 16)
	var center := _brush_layer.map_to_local(_hover_coords)
	var rect := Rect2(center - cell * 0.5, cell)
	_brush.draw_rect(rect, Color(0.35, 0.75, 1.0, 0.18), true)
	_brush.draw_rect(rect, Color(0.4, 0.8, 1.0, 0.9), false, 2.0)


func _load_tileset(path: String) -> TileSet:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as TileSet


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()
