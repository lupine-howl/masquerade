@tool
class_name BuildPanel
extends PanelContainer

## Level-build panel: terrain/water tile painting, entity scene placement, level save.

signal tile_selected(tilemap: String, source_id: int, atlas_coords: Vector2i)
signal level_saved(path: String)

const ENTITIES_TAB_NAME := "Entities"
const TILE_BUTTON_SIZE := 40
const TILE_VISIBLE_ROWS := 3
const ENTITY_PICK_RADIUS := 40.0

enum TabKind { TILE_LAYER, ENTITIES }

var _tile_layers: Array[Dictionary] = []

var _tab_strip: VBoxContainer
var _header_row: HBoxContainer
var _source_row: HFlowContainer
var _entity_grid: GridContainer
var _tile_atlas_picker: TileAtlasPicker
var _atlas_message: Label
var _header_label: Label
var _selected_label: Label
var _debug_label: Label
var _dirty_label: Label
var _save_button: Button
var _source_caption: Label
var _tiles_caption: Label
var _source_scroll: ScrollContainer
var _tile_scroll: ScrollContainer

var _tab_buttons: Array[Button] = []
var _source_buttons: Array[Button] = []
var _entity_buttons: Array[Button] = []
var _category_buttons: Array[Button] = []

var _active_tab_kind: TabKind = TabKind.TILE_LAYER
var _current_tilemap_index: int = -1
var _current_source_id: int = -1
var _selected_entity_button: Button = null
var _selected_entity_scene: PackedScene = null
var _selected_entity: Node2D = null
var _entity_category: String = "All"
var _entity_entries: Array[Dictionary] = []

var _paint_enabled: bool = false
var paint_enabled: bool:
	get:
		return _paint_enabled
	set(value):
		_paint_enabled = value
		if value:
			refresh_tile_layers()
		else:
			_set_brush_visible(false)
			_clear_entity_selection()
			_dragging_entity = false

var _has_tile_selection: bool = false
var _paint_source_id: int = -1
var _paint_coords: Vector2i = Vector2i.ZERO
var _paint_stamps: Array[Dictionary] = []
var _paint_selection_size: Vector2i = Vector2i.ONE
var _paint_brush_size: Vector2i = Vector2i.ONE
var _last_paint_map_coords: Vector2i = Vector2i(-99999, -99999)

var _brush: Node2D = null
var _brush_layer: TileMapLayer = null
var _hover_coords: Vector2i = Vector2i.ZERO
var _brush_visible: bool = false
var _dragging_entity: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2.ZERO
	if not Engine.is_editor_hint():
		set_process_input(true)
		set_process_unhandled_input(true)
	BuildPaintDebug.on_log = _on_debug_log
	_entity_entries = EntityPalette.load_entries()
	_build_ui()
	refresh_tile_layers()
	if not _tile_layers.is_empty():
		_select_tab(TabKind.TILE_LAYER, 0)
	else:
		_select_tab(TabKind.ENTITIES, -1)


func refresh_tile_layers() -> void:
	var scene := get_tree().current_scene if is_inside_tree() else null
	_tile_layers = TileLayerCatalog.discover(scene)
	_populate_tabs()
	if _active_tab_kind == TabKind.TILE_LAYER:
		if _tile_layers.is_empty():
			_select_tab(TabKind.ENTITIES, -1)
		elif _current_tilemap_index < 0 or _current_tilemap_index >= _tile_layers.size():
			_select_tab(TabKind.TILE_LAYER, 0)
		else:
			_select_tab(TabKind.TILE_LAYER, _current_tilemap_index)


func refresh_dirty_label() -> void:
	_refresh_dirty_label()


func notify_saved(path: String) -> void:
	_refresh_dirty_label()
	level_saved.emit(path)
	_selected_label.text = "Saved %s" % path.get_file()


func notify_save_failed(error: String) -> void:
	_selected_label.text = error
	push_warning("BuildPanel: %s" % error)


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

	_header_row = HBoxContainer.new()
	_header_row.add_theme_constant_override("separation", 8)
	main_col.add_child(_header_row)

	_header_label = Label.new()
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_label.add_theme_font_size_override("font_size", PoseTabStyles.PANEL_FONT_SIZE)
	_header_label.text = "Build"
	_header_row.add_child(_header_label)

	_dirty_label = Label.new()
	_dirty_label.add_theme_font_size_override("font_size", PoseTabStyles.CAPTION_FONT_SIZE)
	_dirty_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.45))
	_dirty_label.text = ""
	_header_row.add_child(_dirty_label)

	_save_button = Button.new()
	_save_button.text = "Save"
	_save_button.focus_mode = Control.FOCUS_NONE
	_save_button.add_theme_font_size_override("font_size", PoseTabStyles.CAPTION_FONT_SIZE)
	_save_button.pressed.connect(_on_save_pressed)
	_header_row.add_child(_save_button)

	_source_caption = Label.new()
	_source_caption.add_theme_font_size_override("font_size", PoseTabStyles.CAPTION_FONT_SIZE)
	_source_caption.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	_source_caption.text = "Tilesets"
	main_col.add_child(_source_caption)

	_source_scroll = ScrollContainer.new()
	_source_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_source_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_source_scroll.custom_minimum_size = Vector2(0, 28)
	_source_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_col.add_child(_source_scroll)

	_source_row = HFlowContainer.new()
	_source_row.add_theme_constant_override("h_separation", 3)
	_source_row.add_theme_constant_override("v_separation", 3)
	_source_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_scroll.add_child(_source_row)

	_tiles_caption = Label.new()
	_tiles_caption.add_theme_font_size_override("font_size", PoseTabStyles.CAPTION_FONT_SIZE)
	_tiles_caption.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	_tiles_caption.text = "Atlas"
	main_col.add_child(_tiles_caption)

	_tile_scroll = ScrollContainer.new()
	_tile_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_tile_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_tile_scroll.custom_minimum_size = Vector2(0, TILE_VISIBLE_ROWS * (TILE_BUTTON_SIZE + 4))
	_tile_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tile_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	main_col.add_child(_tile_scroll)

	_tile_atlas_picker = TileAtlasPicker.new()
	_tile_atlas_picker.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_tile_atlas_picker.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tile_atlas_picker.selection_changed.connect(_on_atlas_selection_changed)
	_tile_scroll.add_child(_tile_atlas_picker)

	_entity_grid = GridContainer.new()
	_entity_grid.add_theme_constant_override("h_separation", 4)
	_entity_grid.add_theme_constant_override("v_separation", 4)
	_entity_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_entity_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_entity_grid.visible = false
	_tile_scroll.add_child(_entity_grid)

	_atlas_message = Label.new()
	_atlas_message.add_theme_font_size_override("font_size", PoseTabStyles.CAPTION_FONT_SIZE)
	_atlas_message.visible = false
	_tile_scroll.add_child(_atlas_message)

	_selected_label = Label.new()
	_selected_label.add_theme_font_size_override("font_size", PoseTabStyles.CAPTION_FONT_SIZE)
	_selected_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	_selected_label.text = "No tile selected"
	main_col.add_child(_selected_label)

	_debug_label = Label.new()
	_debug_label.add_theme_font_size_override("font_size", 8)
	_debug_label.add_theme_color_override("font_color", Color(0.55, 0.8, 0.55))
	_debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_debug_label.visible = BuildPaintDebug.enabled
	main_col.add_child(_debug_label)


func _populate_tabs() -> void:
	_clear_children(_tab_strip)
	_tab_buttons.clear()
	for i in _tile_layers.size():
		var entry: Dictionary = _tile_layers[i]
		var layer_name := String(entry.name)
		var btn := PoseTabStyles.make_tab_button(layer_name, "Tile layer: %s" % layer_name)
		PoseTabStyles.apply_tab_button(btn, false, false)
		btn.pressed.connect(_select_tab.bind(TabKind.TILE_LAYER, i))
		_tab_strip.add_child(btn)
		_tab_buttons.append(btn)

	var entities_btn := PoseTabStyles.make_tab_button(ENTITIES_TAB_NAME, "Place scene instances")
	PoseTabStyles.apply_tab_button(entities_btn, false, false)
	entities_btn.pressed.connect(_select_tab.bind(TabKind.ENTITIES, -1))
	_tab_strip.add_child(entities_btn)
	_tab_buttons.append(entities_btn)


func _select_tab(kind: TabKind, tile_index: int) -> void:
	_active_tab_kind = kind
	_current_tilemap_index = tile_index if kind == TabKind.TILE_LAYER else -1
	_clear_entity_selection()
	_clear_tile_selection()

	for i in _tab_buttons.size():
		var active := false
		if kind == TabKind.ENTITIES:
			active = i == _tab_buttons.size() - 1
		else:
			active = i == tile_index
		PoseTabStyles.apply_tab_button(_tab_buttons[i], active, false)

	if kind == TabKind.ENTITIES:
		_header_label.text = "Build — Entities"
		_source_caption.text = "Category"
		_tiles_caption.text = "Scenes"
		_show_tile_palette_mode(false)
		_show_entities_palette()
	else:
		var entry: Dictionary = _tile_layers[tile_index]
		_header_label.text = "Build — %s" % entry.name
		_source_caption.text = "Tilesets"
		_tiles_caption.text = "Atlas"
		_show_tile_palette_mode(true)
		var layer := _get_current_tile_layer()
		_populate_tile_sources(layer.tile_set if layer else null)


func _show_tile_palette_mode(atlas_mode: bool) -> void:
	_tile_atlas_picker.visible = atlas_mode
	_atlas_message.visible = false
	_entity_grid.visible = not atlas_mode
	if atlas_mode:
		_tile_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	else:
		_tile_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


func _show_entities_palette() -> void:
	_clear_children(_source_row)
	_source_buttons.clear()
	_category_buttons.clear()

	for category in EntityPalette.CATEGORIES:
		var btn := Button.new()
		btn.text = category
		btn.focus_mode = Control.FOCUS_NONE
		btn.toggle_mode = true
		btn.add_theme_font_size_override("font_size", PoseTabStyles.CAPTION_FONT_SIZE)
		btn.pressed.connect(_select_entity_category.bind(category))
		_source_row.add_child(btn)
		_category_buttons.append(btn)

	_select_entity_category(_entity_category)


func _select_entity_category(category: String) -> void:
	_entity_category = category
	for btn in _category_buttons:
		btn.set_pressed_no_signal(btn.text == category)
	_populate_entity_grid()


func _populate_entity_grid() -> void:
	_clear_children(_entity_grid)
	_entity_buttons.clear()
	_selected_entity_button = null
	_selected_entity_scene = null

	var shown := 0
	for entry in _entity_entries:
		if _entity_category != "All" and String(entry.category) != _entity_category:
			continue
		var tex: Texture2D = entry.texture
		var btn := _make_tile_button(tex)
		btn.tooltip_text = String(entry.label)
		btn.pressed.connect(_on_entity_pressed.bind(btn, entry))
		_entity_grid.add_child(btn)
		_entity_buttons.append(btn)
		shown += 1

	_update_entity_grid_columns()

	if shown == 0:
		var empty := Label.new()
		empty.text = "(no scenes)"
		empty.add_theme_font_size_override("font_size", PoseTabStyles.CAPTION_FONT_SIZE)
		_entity_grid.add_child(empty)
		_selected_label.text = "No scene selected"
	else:
		_selected_label.text = "LMB place/select/drag · RMB erase · Del remove · Ctrl pans camera"


func _on_entity_pressed(btn: Button, entry: Dictionary) -> void:
	if _selected_entity_button and is_instance_valid(_selected_entity_button):
		_style_tile_button(_selected_entity_button, false)
	_selected_entity_button = btn
	_style_tile_button(btn, true)
	_selected_entity_scene = entry.scene as PackedScene
	_selected_label.text = "Selected: %s" % entry.label


func _populate_tile_sources(tileset: TileSet) -> void:
	_clear_children(_source_row)
	_source_buttons.clear()
	_clear_tile_selection()
	_atlas_message.visible = false
	_tile_atlas_picker.visible = true

	if tileset == null:
		_tile_atlas_picker.clear_selection()
		_atlas_message.text = "(tileset not found)"
		_atlas_message.visible = true
		_tile_atlas_picker.visible = false
		_selected_label.text = "No tile selected"
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
	_clear_tile_selection()
	_atlas_message.visible = false

	var atlas := source as TileSetAtlasSource
	if atlas == null:
		_tile_atlas_picker.visible = false
		_atlas_message.text = "Scene-collection tileset (no atlas preview)"
		_atlas_message.visible = true
		return

	if atlas.texture == null or atlas.get_tiles_count() == 0:
		_tile_atlas_picker.visible = false
		_atlas_message.text = "(no tiles)"
		_atlas_message.visible = true
		return

	_tile_atlas_picker.visible = true
	_tile_atlas_picker.set_source(atlas, source_id)
	_selected_label.text = "Drag on atlas to select · LMB paint · RMB erase · Ctrl pans camera"


func _update_entity_grid_columns() -> void:
	if _entity_grid == null:
		return
	var count := _entity_buttons.size()
	if count == 0:
		_entity_grid.columns = 1
		return
	_entity_grid.columns = maxi(1, ceili(float(count) / float(TILE_VISIBLE_ROWS)))


func _make_tile_button(tex: Texture2D) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(TILE_BUTTON_SIZE, TILE_BUTTON_SIZE)
	btn.focus_mode = Control.FOCUS_NONE
	btn.icon = tex
	btn.expand_icon = true
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


func _on_debug_log(text: String) -> void:
	if _debug_label:
		_debug_label.text = text


func _on_atlas_selection_changed(stamps: Array[Dictionary], source_id: int, selection_rect: Rect2i) -> void:
	_paint_stamps = stamps.duplicate()
	_paint_source_id = source_id
	_paint_selection_size = selection_rect.size
	_paint_brush_size = _compute_brush_map_size()
	_has_tile_selection = not _paint_stamps.is_empty()
	_paint_coords = selection_rect.position
	_last_paint_map_coords = Vector2i(-99999, -99999)
	if not _paint_stamps.is_empty():
		_paint_coords = _paint_stamps[0]["atlas_coords"]
	BuildPaintDebug.log(
		"panel stamps=%d sel=%s brush=%s source=%d layer_idx=%d" % [
			_paint_stamps.size(),
			_paint_selection_size,
			_paint_brush_size,
			_paint_source_id,
			_current_tilemap_index,
		]
	)

	var tilemap_name := "?"
	if _current_tilemap_index >= 0 and _current_tilemap_index < _tile_layers.size():
		tilemap_name = String(_tile_layers[_current_tilemap_index].name)

	if selection_rect.size == Vector2i.ONE:
		_selected_label.text = "Selected: %s / src %d / (%d, %d)" % [
			tilemap_name, source_id, selection_rect.position.x, selection_rect.position.y
		]
		tile_selected.emit(tilemap_name, source_id, selection_rect.position)
	else:
		_selected_label.text = "Selected: %s / src %d / %d×%d pattern at (%d, %d)" % [
			tilemap_name,
			source_id,
			selection_rect.size.x,
			selection_rect.size.y,
			selection_rect.position.x,
			selection_rect.position.y,
		]
		tile_selected.emit(tilemap_name, source_id, selection_rect.position)

	if _brush != null and is_instance_valid(_brush):
		_brush.queue_redraw()


func _clear_tile_selection() -> void:
	if _tile_atlas_picker:
		_tile_atlas_picker.clear_selection()
	_selected_label.text = "No tile selected" if _active_tab_kind == TabKind.TILE_LAYER else _selected_label.text
	_has_tile_selection = false
	_paint_source_id = -1
	_paint_stamps.clear()
	_paint_selection_size = Vector2i.ONE
	_paint_brush_size = Vector2i.ONE
	_paint_coords = Vector2i.ZERO
	_last_paint_map_coords = Vector2i(-99999, -99999)


func _source_label(source: TileSetSource, source_id: int) -> String:
	var atlas := source as TileSetAtlasSource
	if atlas != null and atlas.texture != null:
		var path: String = atlas.texture.resource_path
		if path != "":
			return path.get_file().get_basename()
	return "Source %d" % source_id


func _compute_brush_map_size() -> Vector2i:
	if _paint_stamps.size() <= 1:
		return Vector2i.ONE
	return _paint_selection_size


func _input(event: InputEvent) -> void:
	if _try_process_build_input(event, "panel_input"):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _try_process_build_input(event, "panel_unhandled"):
		get_viewport().set_input_as_handled()


func _try_process_build_input(event: InputEvent, channel: String) -> bool:
	if Engine.is_editor_hint() or not paint_enabled:
		return false
	return process_build_input(event, channel)


func process_build_input(event: InputEvent, channel: String = "hud") -> bool:
	if not paint_enabled:
		return false
	if _is_camera_modifier_held():
		return false

	if event is InputEventMouseButton and event.pressed:
		var btn := (event as InputEventMouseButton).button_index
		if btn == MOUSE_BUTTON_LEFT or btn == MOUSE_BUTTON_RIGHT:
			BuildPaintDebug.log(
				"%s mouse btn=%d tab=%d stamps=%d enabled=%s editor=%s" % [
					channel,
					btn,
					_active_tab_kind,
					_paint_stamps.size(),
					paint_enabled,
					Engine.is_editor_hint(),
				]
			)

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			if _selected_entity and is_instance_valid(_selected_entity):
				_selected_entity.queue_free()
				_clear_entity_selection()
				LevelSave.mark_dirty()
				_refresh_dirty_label()
				return true
			return false

	if event is InputEventMouseButton:
		if _active_tab_kind == TabKind.ENTITIES:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_handle_entity_left_press()
				else:
					_dragging_entity = false
				return true
			if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				_erase_entity_at_mouse()
				return true
			return false
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_paint_tile_at_mouse(false)
				return true
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_paint_tile_at_mouse(true)
				return true
		elif not event.pressed and _active_tab_kind == TabKind.TILE_LAYER:
			_last_paint_map_coords = Vector2i(-99999, -99999)
		return false

	if event is InputEventMouseMotion:
		_update_brush_hover()
		if _active_tab_kind == TabKind.ENTITIES and _dragging_entity and _selected_entity:
			_move_selected_entity_to_mouse()
			return true
		if _active_tab_kind == TabKind.TILE_LAYER:
			var mask := (event as InputEventMouseMotion).button_mask
			if mask & MOUSE_BUTTON_MASK_LEFT:
				_paint_tile_at_mouse(false)
				return true
			if mask & MOUSE_BUTTON_MASK_RIGHT:
				_paint_tile_at_mouse(true)
				return true
	return false


func _is_camera_modifier_held() -> bool:
	return Input.is_key_pressed(KEY_CTRL)


func _handle_entity_left_press() -> void:
	var picked := _pick_entity_at_mouse()
	if picked:
		_set_selected_entity(picked)
		_dragging_entity = true
		return
	if _selected_entity_scene != null:
		_place_entity_at_mouse()
		return
	_clear_entity_selection()


func _move_selected_entity_to_mouse() -> void:
	if not _selected_entity or not is_instance_valid(_selected_entity):
		return
	var snapped := _snap_world_to_grid(_get_world_mouse_position())
	if _selected_entity.global_position.distance_to(snapped) < 0.5:
		return
	_selected_entity.global_position = snapped
	LevelSave.mark_dirty()
	_refresh_dirty_label()


func _place_entity_at_mouse() -> void:
	if _selected_entity_scene == null:
		return
	var container := _find_entities_container()
	if container == null:
		push_warning("BuildPanel: no Enemies container in the current level.")
		return
	var instance := _selected_entity_scene.instantiate()
	if not instance is Node2D:
		instance.queue_free()
		push_warning("BuildPanel: entity root must be Node2D.")
		return
	var node := instance as Node2D
	node.global_position = _snap_world_to_grid(_get_world_mouse_position())
	container.add_child(node)
	LevelAuthoring.prepare_placed_entity(node)
	_set_selected_entity(node)
	LevelSave.mark_dirty()
	_refresh_dirty_label()


func _erase_entity_at_mouse() -> void:
	var entity := _pick_entity_at_mouse()
	if entity == null:
		return
	if _selected_entity == entity:
		_clear_entity_selection()
	entity.queue_free()
	LevelSave.mark_dirty()
	_refresh_dirty_label()


func _pick_entity_at_mouse() -> Node2D:
	return _pick_entity_near(_get_world_mouse_position())


func _pick_entity_near(world: Vector2) -> Node2D:
	var container := _find_entities_container()
	if container == null:
		return null
	var snap := _snap_world_to_grid(world)
	var best: Node2D = null
	var best_dist := ENTITY_PICK_RADIUS
	for child in container.get_children():
		var node := child as Node2D
		if node == null or not is_instance_valid(node):
			continue
		var dist: float = node.global_position.distance_to(snap)
		if dist <= best_dist:
			best = node
			best_dist = dist
	return best


func _set_selected_entity(entity: Node2D) -> void:
	if _selected_entity and is_instance_valid(_selected_entity):
		_selected_entity.modulate = Color.WHITE
	_selected_entity = entity
	if _selected_entity:
		_selected_entity.modulate = Color(1.1, 1.1, 0.85)
		_selected_label.text = "Selected instance: %s" % _selected_entity.name


func _clear_entity_selection() -> void:
	if _selected_entity and is_instance_valid(_selected_entity):
		_selected_entity.modulate = Color.WHITE
	_selected_entity = null


func _paint_tile_at_mouse(erase: bool) -> void:
	if not erase and not _has_tile_selection:
		BuildPaintDebug.log("paint blocked: no selection (stamps=%d)" % _paint_stamps.size())
		return
	var layer := _get_current_tile_layer()
	if layer == null:
		BuildPaintDebug.log("paint blocked: no tile layer (idx=%d)" % _current_tilemap_index)
		push_warning("BuildPanel: no tile layer selected.")
		return
	var world := layer.get_global_mouse_position()
	var coords := layer.local_to_map(layer.to_local(world))
	if erase:
		layer.erase_cell(coords)
		LevelSave.mark_dirty()
		_refresh_dirty_label()
		BuildPaintDebug.log("erased cell %s on %s" % [coords, layer.name])
		return
	if coords == _last_paint_map_coords:
		BuildPaintDebug.log("paint skipped: same cell %s" % coords)
		return
	_last_paint_map_coords = coords
	if layer.tile_set == null:
		BuildPaintDebug.log("paint blocked: layer '%s' has no tileset" % layer.name)
		return
	if not layer.tile_set.has_source(_paint_source_id):
		BuildPaintDebug.log(
			"paint blocked: layer '%s' missing source %d (sources=%d)" % [
				layer.name, _paint_source_id, layer.tile_set.get_source_count()
			]
		)
		push_warning("BuildPanel: layer '%s' uses a different tileset (no source %d)." % [layer.name, _paint_source_id])
		return
	_stamp_paint_at(layer, coords)
	LevelSave.mark_dirty()
	_refresh_dirty_label()


func _stamp_paint_at(layer: TileMapLayer, origin: Vector2i) -> void:
	var painted := false
	for stamp in _paint_stamps:
		var rel: Vector2i = stamp["rel"]
		layer.set_cell(
			origin + rel,
			int(stamp["source_id"]),
			stamp["atlas_coords"],
			int(stamp["alternative"])
		)
		painted = true
	if not painted and _has_tile_selection and _paint_source_id >= 0:
		layer.set_cell(origin, _paint_source_id, _paint_coords)
		painted = true
	if not painted:
		BuildPaintDebug.log("stamp failed: no cells at origin %s" % origin)
		push_warning("BuildPanel: paint skipped — no stamp cells for source %d." % _paint_source_id)
		return
	BuildPaintDebug.log("stamped %d cell(s) at %s on %s" % [_paint_stamps.size(), origin, layer.name])
	layer.update_internals()
	layer.queue_redraw()


func _find_target_layer(layer_name: String) -> TileMapLayer:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var node := scene.find_child(layer_name, true, false)
	return node as TileMapLayer


func _get_current_tile_layer() -> TileMapLayer:
	if _current_tilemap_index < 0 or _current_tilemap_index >= _tile_layers.size():
		return null
	return _find_target_layer(String(_tile_layers[_current_tilemap_index].node_name))


func _find_entities_container() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("Enemies")


func _get_snap_layer() -> TileMapLayer:
	return _find_target_layer("Terrain")


func _get_world_mouse_position() -> Vector2:
	var layer := _get_snap_layer()
	if layer:
		return layer.get_global_mouse_position()
	return Vector2.ZERO


func _snap_world_to_grid(world: Vector2) -> Vector2:
	var layer := _get_snap_layer()
	if layer == null:
		return world
	var local := layer.to_local(world)
	var map_coords := layer.local_to_map(local)
	return layer.to_global(layer.map_to_local(map_coords))


func suppress_brush() -> void:
	_set_brush_visible(false)


func _update_brush_hover() -> void:
	if not paint_enabled:
		_set_brush_visible(false)
		return

	var layer := _get_brush_layer()
	if layer == null:
		_set_brush_visible(false)
		return

	_ensure_brush(layer)
	var world := layer.get_global_mouse_position()
	_hover_coords = layer.local_to_map(layer.to_local(world))
	_set_brush_visible(true)
	_brush.queue_redraw()


func _get_brush_layer() -> TileMapLayer:
	if _active_tab_kind == TabKind.ENTITIES:
		return _get_snap_layer()
	return _get_current_tile_layer()


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
	var cell := Vector2(ts.tile_size) if ts else Vector2(64, 64)
	var half := cell * 0.5
	var brush_size := _paint_brush_size if _has_tile_selection else Vector2i.ONE
	var top_center := _brush_layer.map_to_local(_hover_coords)
	var bottom_center := _brush_layer.map_to_local(_hover_coords + brush_size - Vector2i.ONE)
	var top_left := top_center - half
	var bottom_right := bottom_center + half
	var rect := Rect2(top_left, bottom_right - top_left)
	_brush.set_meta("debug_brush_rect", rect)
	_brush.set_meta("debug_brush_cells", brush_size)
	_brush.draw_rect(rect, Color(0.35, 0.75, 1.0, 0.18), true)
	_brush.draw_rect(rect, Color(0.4, 0.8, 1.0, 0.9), false, 2.0)


func _on_save_pressed() -> void:
	var result := LevelSave.save_level(get_tree())
	if result.ok:
		_refresh_dirty_label()
		level_saved.emit(String(result.path))
		_selected_label.text = "Saved %s" % result.path.get_file()
	else:
		_selected_label.text = String(result.error)
		push_warning("BuildPanel: %s" % result.error)


func _refresh_dirty_label() -> void:
	if _dirty_label == null:
		return
	_dirty_label.text = "*" if LevelSave.dirty else ""


func _load_tileset(path: String) -> TileSet:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as TileSet


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()
