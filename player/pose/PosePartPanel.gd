class_name PosePartPanel
extends PanelContainer

signal inspector_updated(marker: PoseMarker)

@onready var part_strip: VBoxContainer = %PartStrip
@onready var part_label: Label = %PartLabel
@onready var controlled_check: CheckBox = %ControlledCheck
@onready var pos_label: Label = %PosLabel
@onready var local_pos_label: Label = %LocalPosLabel
@onready var rot_label: Label = %RotLabel
@onready var rot_offset_label: Label = %RotOffsetLabel
@onready var rot_offset_row: HBoxContainer = %RotOffsetRow
@onready var rot_offset_spin: SpinBox = %RotOffsetSpin
@onready var follow_rot_check: CheckBox = %FollowRotCheck
@onready var follow_rot_target_option: OptionButton = %FollowRotTargetOption
@onready var look_at_check: CheckBox = %LookAtCheck
@onready var look_at_target_option: OptionButton = %LookAtTargetOption
@onready var sprite_preview_row: HBoxContainer = %SpritePreviewRow
@onready var part_sprite_preview: TextureRect = %PartSpritePreview
@onready var part_sprite_file_dialog: FileDialog = %PartSpriteFileDialog
@onready var sprite_slot_controls: VBoxContainer = %SpriteSlotControls
@onready var sprite_offset_x: SpinBox = %SpriteOffsetX
@onready var sprite_offset_y: SpinBox = %SpriteOffsetY
@onready var sprite_scale_x: SpinBox = %SpriteScaleX
@onready var sprite_scale_y: SpinBox = %SpriteScaleY
@onready var sprite_rot_spin: SpinBox = %SpriteRotSpin
@onready var accessory_section: VBoxContainer = %AccessorySection
@onready var accessory_check: CheckBox = %AccessoryCheck
@onready var accessory_preview_row: HBoxContainer = %AccessoryPreviewRow
@onready var accessory_sprite_preview: TextureRect = %AccessorySpritePreview
@onready var accessory_slot_controls: VBoxContainer = %AccessorySlotControls
@onready var accessory_offset_x: SpinBox = %AccessoryOffsetX
@onready var accessory_offset_y: SpinBox = %AccessoryOffsetY
@onready var accessory_scale_x: SpinBox = %AccessoryScaleX
@onready var accessory_scale_y: SpinBox = %AccessoryScaleY
@onready var accessory_rot_spin: SpinBox = %AccessoryRotSpin

var pose_controller: PoseController
var timeline: TimelineManager
var _get_anim_name: Callable
var _is_auto_recording: Callable
var _on_visuals_refresh: Callable

var _part_buttons: Dictionary = {}
var _marker_order: Array[PoseMarker] = []
var _updating_from_controller: bool = false
var _updating_from_ui: bool = false
var _updating_detail: bool = false
var _swap_target_slot: BodyPartSlot = null

func setup(
	p_controller: PoseController,
	p_timeline: TimelineManager,
	get_anim_name: Callable,
	is_auto_recording: Callable,
	on_visuals_refresh: Callable
) -> void:
	pose_controller = p_controller
	timeline = p_timeline
	_get_anim_name = get_anim_name
	_is_auto_recording = is_auto_recording
	_on_visuals_refresh = on_visuals_refresh

func _ready() -> void:
	rot_offset_spin.value_changed.connect(_on_rot_offset_changed)
	follow_rot_check.toggled.connect(_on_follow_rot_toggled)
	follow_rot_target_option.item_selected.connect(_on_follow_rot_target_selected)
	look_at_check.toggled.connect(_on_look_at_toggled)
	look_at_target_option.item_selected.connect(_on_look_at_target_selected)
	controlled_check.toggled.connect(_on_controlled_toggled)
	%BtnSwapSibling.pressed.connect(_on_swap_sibling_pressed)
	%BtnZeroRot.pressed.connect(_on_zero_rotation_pressed)
	part_sprite_preview.gui_input.connect(_on_sprite_preview_gui_input)
	part_sprite_file_dialog.file_selected.connect(_on_sprite_file_selected)
	sprite_offset_x.value_changed.connect(_on_sprite_offset_changed)
	sprite_offset_y.value_changed.connect(_on_sprite_offset_changed)
	sprite_scale_x.value_changed.connect(_on_sprite_scale_changed)
	sprite_scale_y.value_changed.connect(_on_sprite_scale_changed)
	sprite_rot_spin.value_changed.connect(_on_sprite_rot_changed)
	accessory_check.toggled.connect(_on_accessory_toggled)
	accessory_sprite_preview.gui_input.connect(_on_accessory_preview_gui_input)
	accessory_offset_x.value_changed.connect(_on_accessory_offset_changed)
	accessory_offset_y.value_changed.connect(_on_accessory_offset_changed)
	accessory_scale_x.value_changed.connect(_on_accessory_scale_changed)
	accessory_scale_y.value_changed.connect(_on_accessory_scale_changed)
	accessory_rot_spin.value_changed.connect(_on_accessory_rot_changed)
	call_deferred("_apply_compact_layout")


func _apply_compact_layout() -> void:
	var part_info := get_node_or_null("ContentRow/Panel/MarginContainer2/PartInfo") as VBoxContainer
	if part_info == null:
		return

	var header := part_info.get_node_or_null("HBoxContainer")
	var sprite_preview_row := part_info.get_node_or_null("SpritePreviewRow") as Control
	var sprite_slot_controls := part_info.get_node_or_null("SpriteSlotControls") as Control
	var accessory_section := part_info.get_node_or_null("AccessorySection") as Control
	var details_vbox := part_info.get_node_or_null("VBoxContainer") as Control

	var body_row := HBoxContainer.new()
	body_row.name = "BodyRow"
	body_row.add_theme_constant_override("separation", 10)
	body_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var col_sprites := VBoxContainer.new()
	col_sprites.add_theme_constant_override("separation", 4)
	col_sprites.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var col_spins := VBoxContainer.new()
	col_spins.add_theme_constant_override("separation", 2)
	col_spins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_spins.size_flags_stretch_ratio = 1.2

	var col_pose := VBoxContainer.new()
	col_pose.add_theme_constant_override("separation", 2)
	col_pose.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var col_constraints := VBoxContainer.new()
	col_constraints.add_theme_constant_override("separation", 2)
	col_constraints.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if sprite_preview_row:
		part_info.remove_child(sprite_preview_row)
		_compact_sprite_preview(sprite_preview_row, 56)
		col_sprites.add_child(sprite_preview_row)

	if accessory_section:
		var acc_toggle := accessory_section.get_node_or_null("AccessoryToggleRow")
		var acc_preview := accessory_section.get_node_or_null("AccessoryPreviewRow")
		var acc_controls := accessory_section.get_node_or_null("AccessorySlotControls")
		if acc_toggle:
			accessory_section.remove_child(acc_toggle)
			col_sprites.add_child(acc_toggle)
		if acc_preview:
			accessory_section.remove_child(acc_preview)
			_compact_sprite_preview(acc_preview, 56)
			col_sprites.add_child(acc_preview)
		if acc_controls:
			accessory_section.remove_child(acc_controls)
			col_spins.add_child(acc_controls)
		if accessory_section.get_child_count() == 0:
			accessory_section.visible = false

	if sprite_slot_controls:
		part_info.remove_child(sprite_slot_controls)
		col_spins.add_child(sprite_slot_controls)

	if details_vbox:
		part_info.remove_child(details_vbox)
		for row_name in ["FollowRotRow", "LookAtRow", "HBoxContainer6"]:
			var row := details_vbox.get_node_or_null(row_name)
			if row:
				details_vbox.remove_child(row)
				col_constraints.add_child(row)
		col_pose.add_child(details_vbox)

	body_row.add_child(col_sprites)
	body_row.add_child(col_spins)
	body_row.add_child(col_pose)
	body_row.add_child(col_constraints)

	if header:
		var header_index := header.get_index()
		part_info.add_child(body_row)
		part_info.move_child(body_row, header_index + 1)
	else:
		part_info.add_child(body_row)

	var content_panel := get_node_or_null("ContentRow/Panel") as Control
	if content_panel:
		content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	custom_minimum_size = Vector2.ZERO
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	PoseTabStyles.bump_fonts_recursive(self, 1)


func _compact_sprite_preview(row: Control, edge: int) -> void:
	for child in row.get_children():
		if child is TextureRect:
			child.custom_minimum_size = Vector2(edge, edge)
	_style_details_panel()
	_style_details_wrapper()
	_style_outer_panel()
	_style_tab_strip()

func _style_tab_strip() -> void:
	var strip_panel := get_node_or_null("ContentRow/TabStripPanel") as PanelContainer
	if not strip_panel:
		return
	PoseTabStyles.apply_left_tab_strip(strip_panel)
	PoseTabStyles.configure_strip_container(part_strip)

func _style_details_panel() -> void:
	var details := get_node_or_null("ContentRow/Panel") as PanelContainer
	if not details:
		return
	PoseTabStyles.apply_content_panel(details, true)

func _style_details_wrapper() -> void:
	var wrapper := get_node_or_null("ContentRow/Panel/MarginContainer2") as MarginContainer
	if wrapper:
		wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrapper.add_theme_constant_override("margin_left", 0)
		wrapper.add_theme_constant_override("margin_top", 5)
		wrapper.add_theme_constant_override("margin_right", 5)
		wrapper.add_theme_constant_override("margin_bottom", 5)

func _style_outer_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	add_theme_stylebox_override("panel", style)

func setup_part_table(markers: Array[PoseMarker]) -> void:
	for child in part_strip.get_children():
		child.queue_free()
	_part_buttons.clear()
	_marker_order.clear()
	for marker in markers:
		if marker.hide_in_pose_ui:
			continue
		_marker_order.append(marker)
		var btn := PoseTabStyles.make_tab_button(marker.name)
		btn.set_meta("marker", marker)
		btn.gui_input.connect(_on_part_button_gui_input.bind(marker))
		_apply_tab_style(btn, false)
		part_strip.add_child(btn)
		_part_buttons[marker] = btn
	sync_selection_from_controller()

func _apply_tab_style(btn: Button, selected: bool) -> void:
	PoseTabStyles.apply_tab_button(btn, selected, false)

func sync_selection_from_controller() -> void:
	_updating_from_controller = true
	for marker in _part_buttons:
		var btn: Button = _part_buttons[marker]
		var selected: bool = pose_controller and marker in pose_controller.active_markers
		_apply_tab_style(btn, selected)
	_updating_from_controller = false
	var primary := pose_controller.get_primary_marker() if pose_controller else null
	_update_part_label(primary)
	refresh_inspector(primary)

func update_inspector_checkboxes(marker: PoseMarker) -> void:
	refresh_inspector(marker)

func refresh_inspector(marker: PoseMarker) -> void:
	_sync_detail_from_marker(marker)
	inspector_updated.emit(marker)

func update_live_readouts(primary_marker: PoseMarker) -> void:
	if primary_marker and primary_marker.slave:
		var pos := primary_marker.global_position
		pos_label.text = "World (%d, %d)" % [round(pos.x), round(pos.y)]
		local_pos_label.text = "Local (%0.1f, %0.1f)" % [primary_marker.position.x, primary_marker.position.y]
		rot_label.text = "Rot %0.1f°" % rad_to_deg(primary_marker.global_rotation)
	elif primary_marker:
		pos_label.text = "World (%d, %d)" % [round(primary_marker.global_position.x), round(primary_marker.global_position.y)]
		local_pos_label.text = "Local (%0.1f, %0.1f)" % [primary_marker.position.x, primary_marker.position.y]
		rot_label.text = "Rot %0.1f°" % rad_to_deg(primary_marker.global_rotation)
	else:
		pos_label.text = "World (--, --)"
		local_pos_label.text = "Local (--, --)"
		rot_label.text = "Rot --"

func request_auto_key(marker: PoseMarker) -> void:
	if _is_auto_recording.is_null() or not _is_auto_recording.call():
		return
	_key_marker_pose(marker)

func key_all_markers() -> void:
	if not pose_controller or not timeline or _get_anim_name.is_null():
		return
	var anim_name: String = _get_anim_name.call()
	_key_with_mirror(func() -> void:
		for m in pose_controller.all_markers:
			timeline.key_marker_pose(anim_name, m)
		if pose_controller.player and timeline.is_path_body_drive_authoring_enabled(anim_name):
			for guide in PathGuideMarker.gather_under(pose_controller.player):
				timeline.key_path_guide_pose(anim_name, guide)
	)
	_refresh_visuals()

func normalize_horizontal() -> void:
	_normalize_axis("x")

func _get_active_markers() -> Array[PoseMarker]:
	if pose_controller and not pose_controller.active_markers.is_empty():
		return pose_controller.active_markers
	var primary := pose_controller.get_primary_marker() if pose_controller else null
	return [primary] if primary else []

func _on_part_button_gui_input(event: InputEvent, marker: PoseMarker) -> void:
	if _updating_from_controller or not pose_controller:
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	_handle_part_selection(marker, mouse_event.shift_pressed, mouse_event.is_command_or_control_pressed())
	get_viewport().set_input_as_handled()

func _handle_part_selection(marker: PoseMarker, shift_pressed: bool, ctrl_pressed: bool) -> void:
	_updating_from_ui = true
	if shift_pressed and not ctrl_pressed and not pose_controller.active_markers.is_empty():
		var anchor := pose_controller.active_markers[0]
		var from_i := _marker_order.find(anchor)
		var to_i := _marker_order.find(marker)
		if from_i >= 0 and to_i >= 0:
			var lo := mini(from_i, to_i)
			var hi := maxi(from_i, to_i)
			var range_markers: Array[PoseMarker] = []
			for i in range(lo, hi + 1):
				range_markers.append(_marker_order[i])
			pose_controller.set_active_markers(range_markers)
	elif ctrl_pressed:
		if marker in pose_controller.active_markers:
			pose_controller.remove_marker_from_selection(marker)
		else:
			pose_controller.add_markers_to_selection([marker])
	else:
		pose_controller.set_active_markers([marker])
	_updating_from_ui = false
	sync_selection_from_controller()

func _sync_detail_from_marker(marker: PoseMarker) -> void:
	_updating_detail = true
	if marker:
		controlled_check.set_pressed_no_signal(marker.is_controlled)
		local_pos_label.text = "Local (%0.1f, %0.1f)" % [marker.position.x, marker.position.y]
		follow_rot_check.set_pressed_no_signal(marker.use_follow_rotation)
		follow_rot_target_option.disabled = not marker.use_follow_rotation
		_populate_constraint_target_option(follow_rot_target_option, marker, marker.follow_rotation_target)
		look_at_check.set_pressed_no_signal(marker.use_look_at)
		look_at_target_option.disabled = not marker.use_look_at
		_populate_constraint_target_option(look_at_target_option, marker, marker.look_at_target)
		_sync_rot_offset_ui(marker)
		_sync_sprite_ui(marker)
	else:
		controlled_check.set_pressed_no_signal(false)
		local_pos_label.text = "Local (--, --)"
		follow_rot_check.set_pressed_no_signal(false)
		follow_rot_target_option.clear()
		follow_rot_target_option.add_item("None")
		look_at_check.set_pressed_no_signal(false)
		look_at_target_option.clear()
		look_at_target_option.add_item("None")
		rot_offset_row.visible = false
		_sync_sprite_ui(null)
	_updating_detail = false

func _sync_sprite_ui(marker: PoseMarker) -> void:
	_sync_primary_sprite_ui(marker)
	_sync_accessory_sprite_ui(marker)

func _sync_primary_sprite_ui(marker: PoseMarker) -> void:
	var slot: BodyPartSlot = _get_body_part_slot(marker)
	var has_slot := slot != null
	sprite_preview_row.visible = has_slot
	sprite_slot_controls.visible = has_slot
	if has_slot:
		part_sprite_preview.texture = slot.get_display_texture()
		_apply_slot_controls_to_ui(slot, sprite_offset_x, sprite_offset_y, sprite_scale_x, sprite_scale_y, sprite_rot_spin)
	else:
		part_sprite_preview.texture = null

func _sync_accessory_sprite_ui(marker: PoseMarker) -> void:
	var slot: BodyPartSlot = _get_accessory_part_slot(marker)
	var has_slot := slot != null
	var acc_toggle_row := accessory_check.get_parent() as Control if is_instance_valid(accessory_check) else null
	if acc_toggle_row:
		acc_toggle_row.visible = has_slot
	if not has_slot:
		if is_instance_valid(accessory_preview_row):
			accessory_preview_row.visible = false
		if is_instance_valid(accessory_slot_controls):
			accessory_slot_controls.visible = false
		if is_instance_valid(accessory_sprite_preview):
			accessory_sprite_preview.texture = null
		return
	accessory_check.set_pressed_no_signal(slot.visible)
	var show_details := slot.visible
	accessory_preview_row.visible = show_details
	accessory_slot_controls.visible = show_details
	if show_details:
		accessory_sprite_preview.texture = slot.get_display_texture()
		_apply_slot_controls_to_ui(slot, accessory_offset_x, accessory_offset_y, accessory_scale_x, accessory_scale_y, accessory_rot_spin)
	else:
		accessory_sprite_preview.texture = null

func _apply_slot_controls_to_ui(
	slot: BodyPartSlot,
	offset_x: SpinBox,
	offset_y: SpinBox,
	scale_x: SpinBox,
	scale_y: SpinBox,
	rot_spin: SpinBox
) -> void:
	offset_x.set_value_no_signal(slot.offset.x)
	offset_y.set_value_no_signal(slot.offset.y)
	scale_x.set_value_no_signal(slot.slot_scale.x)
	scale_y.set_value_no_signal(slot.slot_scale.y)
	rot_spin.set_value_no_signal(slot.slot_rotation_degrees)

func _read_slot_controls_from_ui(
	offset_x: SpinBox,
	offset_y: SpinBox,
	scale_x: SpinBox,
	scale_y: SpinBox,
	rot_spin: SpinBox
) -> Dictionary:
	return {
		"offset": Vector2(offset_x.value, offset_y.value),
		"slot_scale": Vector2(scale_x.value, scale_y.value),
		"slot_rotation_degrees": rot_spin.value,
	}

func _sync_sprite_preview(marker: PoseMarker) -> void:
	_sync_sprite_ui(marker)

func _get_body_part_slot(marker: PoseMarker) -> BodyPartSlot:
	if marker == null or marker.body_part_slot == null:
		return null
	var slot := marker.body_part_slot
	if not is_instance_valid(slot):
		return null
	return slot

func _get_accessory_part_slot(marker: PoseMarker) -> BodyPartSlot:
	if marker == null or marker.accessory_part_slot == null:
		return null
	var slot := marker.accessory_part_slot
	if not is_instance_valid(slot):
		return null
	return slot

func _get_primary_accessory_part_slot() -> BodyPartSlot:
	if not pose_controller:
		return null
	return _get_accessory_part_slot(pose_controller.get_primary_marker())

func _get_primary_body_part_slot() -> BodyPartSlot:
	if not pose_controller:
		return null
	return _get_body_part_slot(pose_controller.get_primary_marker())

func _on_sprite_offset_changed(_value: float) -> void:
	if _updating_detail:
		return
	var slot := _get_primary_body_part_slot()
	if slot == null:
		return
	var values := _read_slot_controls_from_ui(sprite_offset_x, sprite_offset_y, sprite_scale_x, sprite_scale_y, sprite_rot_spin)
	slot.offset = values.offset
	_auto_key_body_part_slot(slot)

func _on_sprite_scale_changed(_value: float) -> void:
	if _updating_detail:
		return
	var slot := _get_primary_body_part_slot()
	if slot == null:
		return
	var values := _read_slot_controls_from_ui(sprite_offset_x, sprite_offset_y, sprite_scale_x, sprite_scale_y, sprite_rot_spin)
	slot.slot_scale = values.slot_scale
	_auto_key_body_part_slot(slot)

func _on_sprite_rot_changed(value: float) -> void:
	if _updating_detail:
		return
	var slot := _get_primary_body_part_slot()
	if slot == null:
		return
	slot.slot_rotation_degrees = value
	_auto_key_body_part_slot(slot)

func _on_accessory_toggled(enabled: bool) -> void:
	if _updating_detail:
		return
	var slot := _get_primary_accessory_part_slot()
	if slot == null:
		return
	slot.visible = enabled
	_sync_accessory_sprite_ui(pose_controller.get_primary_marker() if pose_controller else null)
	_auto_key_body_part_slot(slot)

func _on_accessory_offset_changed(_value: float) -> void:
	if _updating_detail:
		return
	var slot := _get_primary_accessory_part_slot()
	if slot == null:
		return
	var values := _read_slot_controls_from_ui(accessory_offset_x, accessory_offset_y, accessory_scale_x, accessory_scale_y, accessory_rot_spin)
	slot.offset = values.offset
	_auto_key_body_part_slot(slot)

func _on_accessory_scale_changed(_value: float) -> void:
	if _updating_detail:
		return
	var slot := _get_primary_accessory_part_slot()
	if slot == null:
		return
	var values := _read_slot_controls_from_ui(accessory_offset_x, accessory_offset_y, accessory_scale_x, accessory_scale_y, accessory_rot_spin)
	slot.slot_scale = values.slot_scale
	_auto_key_body_part_slot(slot)

func _on_accessory_rot_changed(value: float) -> void:
	if _updating_detail:
		return
	var slot := _get_primary_accessory_part_slot()
	if slot == null:
		return
	slot.slot_rotation_degrees = value
	_auto_key_body_part_slot(slot)

func _on_accessory_preview_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	_open_accessory_swap_dialog()
	get_viewport().set_input_as_handled()

func _open_accessory_swap_dialog() -> void:
	if not pose_controller:
		return
	var primary := pose_controller.get_primary_marker()
	if not primary or not primary.accessory_part_slot:
		return
	_swap_target_slot = primary.accessory_part_slot
	part_sprite_file_dialog.popup_centered()

func _on_sprite_preview_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	_open_sprite_swap_dialog()
	get_viewport().set_input_as_handled()

func _open_sprite_swap_dialog() -> void:
	if not pose_controller:
		return
	var primary := pose_controller.get_primary_marker()
	if not primary or not primary.body_part_slot:
		return
	_swap_target_slot = primary.body_part_slot
	part_sprite_file_dialog.popup_centered()

func _on_sprite_file_selected(path: String) -> void:
	var slot := _swap_target_slot
	_swap_target_slot = null
	if slot == null or not is_instance_valid(slot):
		return
	if not slot.set_texture_from_path(path):
		return
	var primary := pose_controller.get_primary_marker() if pose_controller else null
	refresh_inspector(primary)
	_auto_key_body_part_slot(slot)
	_refresh_visuals()

func _auto_key_body_part_slot(slot: BodyPartSlot) -> void:
	if _is_auto_recording.is_null() or not _is_auto_recording.call() or not timeline or _get_anim_name.is_null():
		return
	var anim_name: String = _get_anim_name.call()
	_key_with_mirror(func() -> void:
		timeline.key_body_part_slot(anim_name, slot)
	)

func _sync_rot_offset_ui(marker: PoseMarker) -> void:
	var has_constraint := marker.use_look_at or marker.use_follow_rotation
	rot_offset_row.visible = has_constraint
	if marker.use_look_at and not marker._is_y_buffer_fully_rotated():
		rot_offset_label.text = "Aim Offset°"
		rot_offset_spin.set_value_no_signal(marker.look_at_offset_deg)
	elif marker.use_follow_rotation:
		rot_offset_label.text = "Follow Offset°"
		rot_offset_spin.set_value_no_signal(marker.follow_rotation_offset_deg)

func _populate_constraint_target_option(option: OptionButton, marker: PoseMarker, current_target: Node2D) -> void:
	option.clear()
	option.add_item("None")
	var selected_idx := 0
	if not pose_controller:
		option.select(0)
		return
	var idx := 1
	for m in pose_controller.all_markers:
		if m == marker or m.hide_in_pose_ui:
			continue
		option.add_item(m.name)
		option.set_item_metadata(idx, m)
		if current_target == m:
			selected_idx = idx
		idx += 1
	if current_target and current_target != marker and selected_idx == 0:
		option.add_item(current_target.name)
		option.set_item_metadata(idx, current_target)
		selected_idx = idx
	option.select(selected_idx)

func _update_part_label(primary: PoseMarker) -> void:
	if not pose_controller or pose_controller.active_markers.is_empty():
		part_label.text = "Select a part"
		return
	if pose_controller.active_markers.size() == 1:
		var marker := pose_controller.active_markers[0]
		part_label.text = marker.slave.name if marker.slave else marker.name
		return
	var label_name: String = "Selection"
	if primary:
		label_name = primary.slave.name if primary.slave else primary.name
	part_label.text = "%s +%d" % [label_name, pose_controller.active_markers.size() - 1]

func _on_controlled_toggled(checked: bool) -> void:
	if _updating_detail:
		return
	for marker in _get_active_markers():
		var was_controlled := marker.is_controlled
		if checked:
			marker.take_control()
		else:
			marker.release_control()
		_auto_key_controlled(marker, was_controlled)
	refresh_inspector(pose_controller.get_primary_marker() if pose_controller else null)
	if pose_controller and pose_controller.pose_hud and pose_controller.pose_hud.assistant_panel:
		pose_controller.pose_hud.assistant_panel.sync_ragdoll_toggles()

func _on_rot_offset_changed(value: float) -> void:
	if _updating_detail:
		return
	for marker in _get_active_markers():
		if marker.use_look_at:
			marker.look_at_offset_deg = value
		elif marker.use_follow_rotation:
			marker.follow_rotation_offset_deg = value

func _on_follow_rot_toggled(enabled: bool) -> void:
	if _updating_detail:
		return
	for marker in _get_active_markers():
		marker.use_follow_rotation = enabled
		if enabled:
			marker.use_look_at = false
			marker.follow_rotation_offset_deg = 0.0
			if not marker.follow_rotation_target:
				marker.follow_rotation_target = _default_follow_target(marker)
		_auto_key_property(marker, ":use_follow_rotation", marker.use_follow_rotation)
	_sync_detail_from_marker(pose_controller.get_primary_marker() if pose_controller else null)

func _on_follow_rot_target_selected(index: int) -> void:
	if _updating_detail:
		return
	var target: Node2D = null
	if index > 0:
		target = follow_rot_target_option.get_item_metadata(index) as Node2D
	for marker in _get_active_markers():
		marker.follow_rotation_target = target

func _default_follow_target(marker: PoseMarker) -> Node2D:
	if pose_controller:
		for m in pose_controller.all_markers:
			if m != marker:
				return m
	return null

func _on_look_at_toggled(enabled: bool) -> void:
	if _updating_detail:
		return
	for marker in _get_active_markers():
		marker.use_look_at = enabled
		if enabled:
			marker.use_follow_rotation = false
			if not marker.look_at_target:
				marker.look_at_target = _default_follow_target(marker)
			if marker.look_at_target:
				marker.sync_constraint_offsets_from_rotation()
		_auto_key_property(marker, ":use_look_at", marker.use_look_at)
	_sync_detail_from_marker(pose_controller.get_primary_marker() if pose_controller else null)

func _on_look_at_target_selected(index: int) -> void:
	if _updating_detail:
		return
	var target: Node2D = null
	if index > 0:
		target = look_at_target_option.get_item_metadata(index) as Node2D
	for marker in _get_active_markers():
		marker.look_at_target = target

func _on_swap_sibling_pressed() -> void:
	if not pose_controller or pose_controller.active_markers.is_empty():
		return
	for m in pose_controller.active_markers:
		pose_controller.swap_with_sibling(m)
	refresh_inspector(pose_controller.get_primary_marker())

func _normalize_axis(axis: String) -> void:
	if not pose_controller:
		return
	var primary := pose_controller.get_primary_marker()
	if not primary:
		return
	var delta := -primary.position.x if axis == "x" else -primary.position.y
	if is_zero_approx(delta):
		return
	for marker in _get_active_markers():
		if axis == "x":
			marker.position.x += delta
		else:
			marker.position.y += delta
		request_auto_key(marker)
	refresh_inspector(primary)

func _auto_key_controlled(marker: PoseMarker, previous_value: bool) -> void:
	if _is_auto_recording.is_null() or not _is_auto_recording.call() or not timeline or _get_anim_name.is_null():
		return
	var anim_name: String = _get_anim_name.call()
	timeline.key_marker_controlled(anim_name, marker, previous_value)
	_refresh_visuals()

func _auto_key_property(marker: PoseMarker, property_suffix: String, value: Variant) -> void:
	if _is_auto_recording.is_null() or not _is_auto_recording.call() or not timeline or _get_anim_name.is_null():
		return
	var anim_name: String = _get_anim_name.call()
	timeline.ensure_marker_control_keyed(anim_name, marker)
	timeline.key_property(anim_name, marker, property_suffix, value)
	_refresh_visuals()

func _key_marker_pose(marker: PoseMarker) -> void:
	if not timeline or _get_anim_name.is_null():
		return
	var anim_name: String = _get_anim_name.call()
	_key_with_mirror(func() -> void:
		timeline.key_marker_pose(anim_name, marker)
	)
	marker._reset_marker_ui()

func _key_with_mirror(key_action: Callable) -> void:
	key_action.call()
	if not pose_controller or not timeline.mirror_mode_enabled:
		return
	var mirror_steps := timeline.get_mirror_target_steps()
	if mirror_steps.is_empty():
		return

	var previous_steps := timeline.selected_steps.duplicate()
	var previous_anchor := timeline.step_selection_anchor
	pose_controller.swap_all_siblings()
	timeline.set_step_selection(mirror_steps)
	timeline.step_selection_anchor = mirror_steps[0]
	key_action.call()
	pose_controller.swap_all_siblings()
	timeline.set_step_selection(previous_steps)
	timeline.step_selection_anchor = previous_anchor

func _refresh_visuals() -> void:
	if not _on_visuals_refresh.is_null():
		_on_visuals_refresh.call()

func _on_zero_rotation_pressed() -> void:
	for marker in _get_active_markers():
		if marker.use_look_at:
			marker.look_at_offset_deg = 0.0
		elif marker.use_follow_rotation:
			marker.follow_rotation_offset_deg = 0.0
		elif marker._uses_authored_world_rotation():
			marker.rotation = 0.0
		else:
			marker.global_rotation = 0.0
		if marker.slave and marker.is_controlled:
			var pose_rot := marker._solve_rotation()
			marker.slave.global_rotation = marker._to_slave_rotation(pose_rot)
		request_auto_key(marker)
	refresh_inspector(pose_controller.get_primary_marker() if pose_controller else null)
