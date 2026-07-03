class_name PosePartPanel
extends PanelContainer

signal inspector_updated(marker: PoseMarker)

enum PartColumn { PART = 0, CONTROLLED = 1, FOLLOW_ROT = 2 }

@onready var part_table: Tree = %PartTable
@onready var part_label: Label = %PartLabel
@onready var pos_label: Label = %PosLabel
@onready var rot_label: Label = %RotLabel
@onready var pos_x_spin: SpinBox = %PosXSpin
@onready var pos_y_spin: SpinBox = %PosYSpin
@onready var rot_offset_label: Label = %RotOffsetLabel
@onready var rot_offset_row: HBoxContainer = %RotOffsetRow
@onready var rot_offset_spin: SpinBox = %RotOffsetSpin
@onready var lock_x_check: CheckBox = %LockXCheck
@onready var lock_y_check: CheckBox = %LockYCheck
@onready var follow_rot_check: CheckBox = %FollowRotCheck
@onready var follow_rot_target_option: OptionButton = %FollowRotTargetOption
@onready var look_at_check: CheckBox = %LookAtCheck
@onready var look_at_target_option: OptionButton = %LookAtTargetOption

var pose_controller: PoseController
var timeline: TimelineManager
var _get_anim_name: Callable
var _is_auto_recording: Callable
var _on_visuals_refresh: Callable

var _updating_from_controller: bool = false
var _updating_from_ui: bool = false
var _updating_detail: bool = false
var _tree_selection_queued: bool = false

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
	pos_x_spin.value_changed.connect(_on_pos_x_changed)
	pos_y_spin.value_changed.connect(_on_pos_y_changed)
	rot_offset_spin.value_changed.connect(_on_rot_offset_changed)
	lock_x_check.toggled.connect(_on_lock_x_toggled)
	lock_y_check.toggled.connect(_on_lock_y_toggled)
	follow_rot_check.toggled.connect(_on_follow_rot_toggled)
	follow_rot_target_option.item_selected.connect(_on_follow_rot_target_selected)
	look_at_check.toggled.connect(_on_look_at_toggled)
	look_at_target_option.item_selected.connect(_on_look_at_target_selected)
	%BtnKeyPos.pressed.connect(_on_key_position_pressed)
	%BtnKeyRot.pressed.connect(_on_key_rotation_pressed)
	%BtnKeyAll.pressed.connect(key_all_markers)
	%BtnResetPos.pressed.connect(_on_reset_position_pressed)
	%BtnResetRot.pressed.connect(_on_reset_rotation_pressed)
	%BtnSwapSibling.pressed.connect(_on_swap_sibling_pressed)

func setup_part_table(markers: Array[PoseMarker]) -> void:
	part_table.columns = 3
	part_table.hide_root = true
	part_table.set_column_custom_minimum_width(PartColumn.PART, 100)
	part_table.set_column_expand(PartColumn.PART, true)
	part_table.set_column_custom_minimum_width(PartColumn.CONTROLLED, 28)
	part_table.set_column_custom_minimum_width(PartColumn.FOLLOW_ROT, 28)
	var root := part_table.create_item()
	part_table.set_column_title(PartColumn.PART, "Part")
	part_table.set_column_title(PartColumn.CONTROLLED, "Ctl")
	part_table.set_column_title(PartColumn.FOLLOW_ROT, "Follow")
	part_table.column_titles_visible = true
	part_table.item_selected.connect(_on_table_part_selected)
	part_table.multi_selected.connect(_on_table_part_selected)
	part_table.item_edited.connect(_on_table_cell_edited)
	for marker in markers:
		_add_marker_row(root, marker)

func _add_marker_row(root: TreeItem, marker: PoseMarker) -> void:
	var row := part_table.create_item(root)
	row.set_metadata(PartColumn.PART, marker)
	row.set_text(PartColumn.PART, marker.name)
	row.set_selectable(PartColumn.PART, true)
	_set_tree_checkbox(row, PartColumn.CONTROLLED, marker.is_controlled)
	_set_tree_checkbox(row, PartColumn.FOLLOW_ROT, marker.use_follow_rotation)

func sync_selection_from_controller() -> void:
	if _updating_from_ui or not part_table:
		return
	_updating_from_controller = true
	part_table.deselect_all()
	var item := part_table.get_root().get_first_child()
	while item:
		var marker := item.get_metadata(PartColumn.PART) as PoseMarker
		if pose_controller and marker in pose_controller.active_markers:
			item.select(PartColumn.PART)
		item = item.get_next()
	_updating_from_controller = false
	var primary := pose_controller.get_primary_marker() if pose_controller else null
	_update_part_label(primary)
	refresh_inspector(primary)

func update_inspector_checkboxes(marker: PoseMarker) -> void:
	refresh_inspector(marker)

func refresh_inspector(marker: PoseMarker) -> void:
	_sync_table_animation_columns()
	_sync_detail_from_marker(marker)
	inspector_updated.emit(marker)

func update_live_readouts(primary_marker: PoseMarker) -> void:
	if primary_marker and primary_marker.slave:
		var pos := primary_marker.global_position
		pos_label.text = "    ⚲    Position: (%d, %d)" % [round(pos.x), round(pos.y)]
		rot_label.text = "    ↻    Rotation: %0.1f°" % rad_to_deg(primary_marker.global_rotation)
		if not _updating_detail:
			_sync_detail_position(primary_marker)
	else:
		pos_label.text = "    ⚲    Position: --"
		rot_label.text = "    ↻    Rotation: --"

func request_auto_key(marker: PoseMarker) -> void:
	if _is_auto_recording.is_null() or not _is_auto_recording.call():
		return
	_key_marker_pose(marker)

func key_all_markers() -> void:
	if not pose_controller or not timeline or _get_anim_name.is_null():
		return
	var anim_name: String = _get_anim_name.call()
	for m in pose_controller.all_markers:
		timeline.key_marker_pose(anim_name, m)
	_refresh_visuals()

func _get_active_markers() -> Array[PoseMarker]:
	if pose_controller and not pose_controller.active_markers.is_empty():
		return pose_controller.active_markers
	var primary := pose_controller.get_primary_marker() if pose_controller else null
	return [primary] if primary else []

func _set_tree_checkbox(item: TreeItem, column: int, checked: bool) -> void:
	item.set_cell_mode(column, TreeItem.CELL_MODE_CHECK)
	item.set_checked(column, checked)
	item.set_editable(column, true)

func _is_locked_x(marker: PoseMarker) -> bool:
	return marker.use_min_max_x and is_equal_approx(marker.min_x, marker.max_x)

func _is_locked_y(marker: PoseMarker) -> bool:
	return marker.use_min_max_y and is_equal_approx(marker.min_y, marker.max_y)

func _sync_table_animation_columns() -> void:
	if _updating_from_ui or not part_table:
		return
	var item := part_table.get_root().get_first_child()
	while item:
		var marker := item.get_metadata(PartColumn.PART) as PoseMarker
		if marker:
			item.set_checked(PartColumn.CONTROLLED, marker.is_controlled)
			item.set_checked(PartColumn.FOLLOW_ROT, marker.use_follow_rotation)
		item = item.get_next()

func _sync_detail_from_marker(marker: PoseMarker) -> void:
	_updating_detail = true
	if marker:
		pos_x_spin.set_value_no_signal(marker.position.x)
		pos_y_spin.set_value_no_signal(marker.position.y)
		follow_rot_check.set_pressed_no_signal(marker.use_follow_rotation)
		follow_rot_target_option.disabled = not marker.use_follow_rotation
		_populate_constraint_target_option(follow_rot_target_option, marker, marker.follow_rotation_target)
		look_at_check.set_pressed_no_signal(marker.use_look_at)
		look_at_target_option.disabled = not marker.use_look_at
		_populate_constraint_target_option(look_at_target_option, marker, marker.look_at_target)
		_sync_rot_offset_ui(marker)
		lock_x_check.set_pressed_no_signal(_is_locked_x(marker))
		lock_y_check.set_pressed_no_signal(_is_locked_y(marker))
	else:
		pos_x_spin.set_value_no_signal(0.0)
		pos_y_spin.set_value_no_signal(0.0)
		follow_rot_check.set_pressed_no_signal(false)
		follow_rot_target_option.clear()
		follow_rot_target_option.add_item("None")
		look_at_check.set_pressed_no_signal(false)
		look_at_target_option.clear()
		look_at_target_option.add_item("None")
		rot_offset_row.visible = false
		lock_x_check.set_pressed_no_signal(false)
		lock_y_check.set_pressed_no_signal(false)
	_updating_detail = false

func _sync_detail_position(marker: PoseMarker) -> void:
	_updating_detail = true
	pos_x_spin.set_value_no_signal(marker.position.x)
	pos_y_spin.set_value_no_signal(marker.position.y)
	_sync_rot_offset_ui(marker)
	_updating_detail = false

func _sync_rot_offset_ui(marker: PoseMarker) -> void:
	var has_constraint := marker.use_look_at or marker.use_follow_rotation
	rot_offset_row.visible = has_constraint
	if marker.use_look_at and not marker._is_ground_fully_locked():
		rot_offset_label.text = "   Aim Offset°"
		rot_offset_spin.set_value_no_signal(marker.look_at_offset_deg)
	elif marker.use_follow_rotation:
		rot_offset_label.text = "   Follow Offset°"
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
		if m == marker:
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

func _on_table_part_selected(_item: TreeItem = null, _column: int = 0, _selected: bool = false) -> void:
	if _updating_from_controller or _tree_selection_queued:
		return
	_tree_selection_queued = true
	call_deferred("_process_queued_tree_selection")

func _process_queued_tree_selection() -> void:
	_tree_selection_queued = false
	_updating_from_ui = true
	var selected: Array[PoseMarker] = []
	var item := part_table.get_next_selected(null)
	while item:
		var marker := item.get_metadata(PartColumn.PART) as PoseMarker
		if marker:
			selected.append(marker)
		item = part_table.get_next_selected(item)
	if pose_controller:
		pose_controller.set_active_markers(selected)
		var primary := pose_controller.get_primary_marker()
		_update_part_label(primary)
		_sync_detail_from_marker(primary)
	_updating_from_ui = false

func _update_part_label(primary: PoseMarker) -> void:
	if not primary:
		part_label.text = "None"
	elif primary.slave:
		part_label.text = primary.slave.name
	else:
		part_label.text = primary.name

func _on_table_cell_edited() -> void:
	var edited_item := part_table.get_edited()
	var col := part_table.get_edited_column()
	if not edited_item:
		return
	var marker := edited_item.get_metadata(PartColumn.PART) as PoseMarker
	if not marker:
		return
	match col:
		PartColumn.CONTROLLED:
			if edited_item.is_checked(col):
				marker.take_control()
			else:
				marker.release_control()
			_auto_key_property(marker, ":is_controlled", marker.is_controlled)
		PartColumn.FOLLOW_ROT:
			marker.use_follow_rotation = edited_item.is_checked(col)
			if marker.use_follow_rotation:
				marker.use_look_at = false
				if not marker.follow_rotation_target:
					marker.follow_rotation_target = _default_follow_target(marker)
				if marker.follow_rotation_target:
					marker.sync_constraint_offsets_from_rotation()
			_auto_key_property(marker, ":use_follow_rotation", marker.use_follow_rotation)
	if pose_controller and marker in pose_controller.active_markers:
		_sync_detail_from_marker(pose_controller.get_primary_marker())

func _on_pos_x_changed(value: float) -> void:
	if _updating_detail:
		return
	for marker in _get_active_markers():
		marker.position.x = value
		request_auto_key(marker)

func _on_pos_y_changed(value: float) -> void:
	if _updating_detail:
		return
	for marker in _get_active_markers():
		marker.position.y = value
		request_auto_key(marker)

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
			if not marker.follow_rotation_target:
				marker.follow_rotation_target = _default_follow_target(marker)
			if marker.follow_rotation_target:
				marker.sync_constraint_offsets_from_rotation()
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

func _on_lock_x_toggled(locked: bool) -> void:
	if _updating_detail:
		return
	for marker in _get_active_markers():
		if locked:
			var ref_x := marker.x_constraint_parent.global_position.x if marker.x_constraint_parent else 0.0
			var local_x := marker.global_position.x - ref_x
			marker.use_min_max_x = true
			marker.min_x = local_x
			marker.max_x = local_x
		else:
			marker.use_min_max_x = false

func _on_lock_y_toggled(locked: bool) -> void:
	if _updating_detail:
		return
	for marker in _get_active_markers():
		if locked:
			var ref_y := marker.y_constraint_parent.global_position.y if marker.y_constraint_parent else 0.0
			var local_y := marker.global_position.y - ref_y
			marker.use_min_max_y = true
			marker.min_y = local_y
			marker.max_y = local_y
		else:
			marker.use_min_max_y = false

func _on_swap_sibling_pressed() -> void:
	if not pose_controller or pose_controller.active_markers.is_empty():
		return
	for m in pose_controller.active_markers:
		pose_controller.swap_with_sibling(m)
	refresh_inspector(pose_controller.get_primary_marker())

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
	timeline.key_marker_pose(_get_anim_name.call(), marker)
	marker._reset_marker_ui()

func _refresh_visuals() -> void:
	if not _on_visuals_refresh.is_null():
		_on_visuals_refresh.call()

func _on_key_position_pressed() -> void:
	if not pose_controller:
		return
	for marker in pose_controller.active_markers:
		_key_marker_pose(marker)
	_refresh_visuals()

func _on_key_rotation_pressed() -> void:
	_on_key_position_pressed()

func _on_reset_position_pressed() -> void:
	if not pose_controller or not timeline or _get_anim_name.is_null():
		return
	var anim_name: String = _get_anim_name.call()
	for marker in pose_controller.active_markers:
		timeline.remove_marker_pose_keys(anim_name, marker)
		marker.revert_to_original()
	refresh_inspector(pose_controller.get_primary_marker())
	_refresh_visuals()

func _on_reset_rotation_pressed() -> void:
	_on_reset_position_pressed()
