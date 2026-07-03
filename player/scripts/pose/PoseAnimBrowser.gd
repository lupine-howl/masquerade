class_name PoseAnimBrowser
extends MarginContainer

signal animation_changed(anim_name: String)
signal duration_changed(duration: float)
signal speed_changed(speed: float)

@onready var anim_table: Tree = %AnimTable
@onready var anim_dropdown: OptionButton = %AnimDropdown
@onready var speed_box: SpinBox = %SpeedSpinBox
@onready var duration_box: SpinBox = %DurationSpinBox
@onready var anim_title: Label = %AnimTitle

var timeline: TimelineManager

func setup(p_timeline: TimelineManager) -> void:
	timeline = p_timeline
	_setup_animation_table()

func _ready() -> void:
	speed_box.value_changed.connect(_on_speed_box_changed)
	duration_box.value_changed.connect(_on_duration_changed)
	anim_dropdown.item_selected.connect(_on_dropdown_changed)

func get_current_animation() -> String:
	return anim_dropdown.get_item_text(anim_dropdown.selected) if anim_dropdown.item_count > 0 else ""

func time_to_steps(duration_seconds: float) -> int:
	if not timeline or timeline.step_duration <= 0:
		return 0
	return int(round(duration_seconds / timeline.step_duration))

func steps_to_time(steps: int) -> float:
	if not timeline:
		return 0.0
	return steps * timeline.step_duration

func populate_animations() -> void:
	anim_dropdown.clear()
	if not timeline:
		return
	for anim_name in timeline.get_animations():
		anim_dropdown.add_item(anim_name)
	if anim_dropdown.item_count > 0:
		anim_dropdown.select(0)
	_populate_anim_table()

func select_animation_by_name(anim_name: String) -> void:
	for i in range(anim_dropdown.item_count):
		if anim_dropdown.get_item_text(i) == anim_name:
			if anim_dropdown.selected != i:
				anim_dropdown.select(i)
				_apply_animation_selection(i)
			break

func sync_duration_ui(duration: float) -> void:
	duration_box.set_value_no_signal(duration)

func _setup_animation_table() -> void:
	if not timeline or not timeline.anim_player:
		return

	anim_table.columns = 4
	anim_table.hide_root = true
	anim_table.set_column_expand(0, true)
	anim_table.create_item()
	anim_table.set_column_title(0, "Animation")
	anim_table.set_column_title(1, "Speed")
	anim_table.set_column_title(2, "Steps")
	anim_table.set_column_title(3, "Loop")
	anim_table.column_titles_visible = true
	anim_table.item_selected.connect(_on_anim_row_selected)
	anim_table.item_edited.connect(_on_anim_cell_edited)

func _populate_anim_table() -> void:
	if not timeline or not timeline.anim_player:
		return

	anim_table.clear()
	var root := anim_table.create_item()
	var active_anim_name := get_current_animation()

	for anim_name in timeline.get_animations():
		var anim := timeline.anim_player.get_animation(anim_name)
		var row := anim_table.create_item(root)
		row.set_metadata(0, anim_name)
		row.set_text(0, anim_name)
		row.set_selectable(0, true)
		row.set_text(1, str(timeline.get_speed_scale(anim_name)))
		row.set_editable(1, true)
		row.set_text(2, str(time_to_steps(anim.length)))
		row.set_editable(2, true)
		row.set_cell_mode(3, TreeItem.CELL_MODE_CHECK)
		row.set_checked(3, anim.loop_mode != Animation.LOOP_NONE)
		row.set_editable(3, true)
		if anim_name == active_anim_name:
			row.select(0)

func _on_anim_row_selected() -> void:
	var selected_item := anim_table.get_selected()
	if not selected_item:
		return
	var anim_name := selected_item.get_metadata(0) as String
	for i in range(anim_dropdown.item_count):
		if anim_dropdown.get_item_text(i) == anim_name:
			anim_dropdown.select(i)
			_apply_animation_selection(i)
			break

func _on_anim_cell_edited() -> void:
	var edited_item := anim_table.get_edited()
	var col := anim_table.get_edited_column()
	if not edited_item or not timeline:
		return

	var anim_name := edited_item.get_metadata(0) as String
	var anim := timeline.anim_player.get_animation(anim_name)

	match col:
		1:
			var speed_val := float(edited_item.get_text(col))
			timeline.key_speed_scale(anim_name, speed_val)
			if anim_name == get_current_animation():
				speed_box.set_value_no_signal(speed_val)
				if timeline.anim_player:
					timeline.anim_player.speed_scale = speed_val
		2:
			var target_steps := int(edited_item.get_text(col))
			var next_time := steps_to_time(target_steps)
			timeline.set_length(anim_name, next_time)
			if anim_name == get_current_animation():
				duration_box.set_value_no_signal(next_time)
				duration_changed.emit(next_time)
		3:
			var should_loop := edited_item.is_checked(col)
			anim.loop_mode = Animation.LOOP_LINEAR if should_loop else Animation.LOOP_NONE

func _on_dropdown_changed(index: int) -> void:
	_apply_animation_selection(index)

func _apply_animation_selection(index: int) -> void:
	var current_anim := anim_dropdown.get_item_text(index)
	anim_title.text = current_anim.get_basename()

	var was_playing := false
	if timeline and timeline.anim_player:
		was_playing = timeline.anim_player.is_playing()
		if was_playing:
			timeline.stop()

	if timeline and timeline.anim_player and anim_dropdown.item_count > 0:
		var anim := timeline.anim_player.get_animation(current_anim)
		duration_box.set_value_no_signal(anim.length)
		duration_changed.emit(anim.length)
		var speed := timeline.get_speed_scale(current_anim)
		speed_box.set_value_no_signal(speed)
		timeline.anim_player.speed_scale = speed

	animation_changed.emit(current_anim)

	if was_playing and timeline:
		timeline.play(current_anim)

func _on_speed_box_changed(val: float) -> void:
	var anim := get_current_animation()
	if anim != "" and timeline:
		timeline.key_speed_scale(anim, val)
	if timeline and timeline.anim_player:
		timeline.anim_player.speed_scale = val
	speed_changed.emit(val)

func _on_duration_changed(new_duration: float) -> void:
	if not timeline:
		return
	timeline.set_length(get_current_animation(), new_duration)
	duration_changed.emit(new_duration)
