class_name HomeScreen
extends Control

## Boot screen (M0): browse recent projects, create one from a template,
## open a project into its current level, or delete a project.

const BG_COLOR := Color(0.09, 0.1, 0.13)
const PANEL_COLOR := Color(0.13, 0.145, 0.18)
const ACCENT_COLOR := Color(0.75, 0.8, 0.9)
const MUTED_COLOR := Color(0.55, 0.58, 0.65)
const ERROR_COLOR := Color(0.9, 0.5, 0.45)
const TITLE_FONT_SIZE := 34
const HEADING_FONT_SIZE := 18
const BODY_FONT_SIZE := 14

## Tests disable this to exercise the create flow without a scene change.
var open_on_create := true

var _project_list: VBoxContainer
var _empty_label: Label
var _name_edit: LineEdit
var _template_picker: OptionButton
var _create_button: Button
var _status_label: Label
var _confirm_dialog: ConfirmationDialog
var _pending_delete_slug := ""


func _ready() -> void:
	_build_ui()
	_populate_templates()
	refresh()


## Repopulates the project list from ProjectStore.
func refresh() -> void:
	for child in _project_list.get_children():
		child.queue_free()
	var projects: Array[Dictionary] = ProjectStore.list_projects()
	_empty_label.visible = projects.is_empty()
	for project in projects:
		_project_list.add_child(_make_project_row(project))


## Loads a project and switches to its current level scene.
func open_project(slug: String) -> Dictionary:
	var loaded: Dictionary = ProjectStore.load_project(slug)
	if not loaded.ok:
		_set_status(loaded.error)
		return loaded
	var level_path: String = ProjectStore.get_level_path(int(ProjectStore.current.current_level))
	if level_path.is_empty():
		var error := "Project '%s' has no playable level" % slug
		_set_status(error)
		return {"ok": false, "error": error}
	var err: Error = get_tree().change_scene_to_file(level_path)
	if err != OK:
		var error := "Could not open level: %s" % error_string(err)
		_set_status(error)
		return {"ok": false, "error": error}
	return {"ok": true}


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = BG_COLOR
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(560, 0)
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)

	var title := Label.new()
	title.text = "Masquerade"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", ACCENT_COLOR)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Build and teach 2D games"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	subtitle.add_theme_color_override("font_color", MUTED_COLOR)
	column.add_child(subtitle)

	column.add_child(_make_projects_panel())
	column.add_child(_make_create_panel())

	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	_status_label.add_theme_color_override("font_color", ERROR_COLOR)
	_status_label.text = ""
	column.add_child(_status_label)

	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(_confirm_dialog)


func _make_projects_panel() -> PanelContainer:
	var panel := _make_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var heading := Label.new()
	heading.text = "Projects"
	heading.add_theme_font_size_override("font_size", HEADING_FONT_SIZE)
	box.add_child(heading)

	_empty_label = Label.new()
	_empty_label.text = "No projects yet — create one below to get started."
	_empty_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	_empty_label.add_theme_color_override("font_color", MUTED_COLOR)
	box.add_child(_empty_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	_project_list = VBoxContainer.new()
	_project_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_project_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_project_list)

	return panel


func _make_create_panel() -> PanelContainer:
	var panel := _make_panel()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var heading := Label.new()
	heading.text = "New project"
	heading.add_theme_font_size_override("font_size", HEADING_FONT_SIZE)
	box.add_child(heading)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Project name"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_submitted.connect(func(_text: String) -> void: _on_create_pressed())
	row.add_child(_name_edit)

	_template_picker = OptionButton.new()
	_template_picker.custom_minimum_size = Vector2(160, 0)
	row.add_child(_template_picker)

	_create_button = Button.new()
	_create_button.text = "Create"
	_create_button.pressed.connect(_on_create_pressed)
	row.add_child(_create_button)

	return panel


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_project_row(project: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var open_button := Button.new()
	open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	open_button.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	var modified := Time.get_datetime_string_from_unix_time(int(project.modified_unix), true)
	open_button.text = "%s   —   %s" % [project.name, modified]
	open_button.tooltip_text = "Open project"
	var slug := String(project.slug)
	open_button.pressed.connect(func() -> void: open_project(slug))
	row.add_child(open_button)

	var delete_button := Button.new()
	delete_button.text = "Delete"
	delete_button.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	delete_button.tooltip_text = "Delete project"
	delete_button.pressed.connect(func() -> void: _request_delete(slug, String(project.name)))
	row.add_child(delete_button)

	return row


func _populate_templates() -> void:
	_template_picker.clear()
	for template in ProjectStore.list_templates():
		_template_picker.add_item(String(template.name))
		_template_picker.set_item_metadata(_template_picker.item_count - 1, String(template.id))
	if _template_picker.item_count > 0:
		_template_picker.select(0)


func _selected_template_id() -> String:
	var index := _template_picker.selected
	if index < 0:
		return "platformer"
	return String(_template_picker.get_item_metadata(index))


func _on_create_pressed() -> void:
	var result: Dictionary = ProjectStore.create_project(_name_edit.text, _selected_template_id())
	if not result.ok:
		_set_status(result.error)
		return
	_set_status("")
	_name_edit.clear()
	refresh()
	if open_on_create:
		open_project(String(result.slug))


func _request_delete(slug: String, display_name: String) -> void:
	_pending_delete_slug = slug
	_confirm_dialog.dialog_text = "Delete project \"%s\"?\nThis cannot be undone." % display_name
	_confirm_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	if _pending_delete_slug.is_empty():
		return
	var result: Dictionary = ProjectStore.delete_project(_pending_delete_slug)
	_pending_delete_slug = ""
	_set_status("" if result.ok else String(result.error))
	refresh()


func _set_status(message: String) -> void:
	_status_label.text = message
