# Integration tests for the BuildPanel project level picker.

extends GdUnitTestSuite


const TEST_ROOT := "user://tmp/build_panel_levels_test"

var _saved_root: String


func before_test() -> void:
	_saved_root = ProjectStore.root_dir
	ProjectStore.root_dir = TEST_ROOT
	ProjectStore.close_project()
	_wipe_test_root()


func after_test() -> void:
	_wipe_test_root()
	ProjectStore.root_dir = _saved_root
	ProjectStore.close_project()
	LevelSave.clear_dirty()


func _wipe_test_root() -> void:
	if DirAccess.dir_exists_absolute(TEST_ROOT):
		ProjectStore._remove_recursive(TEST_ROOT)


func _make_panel() -> BuildPanel:
	var panel := auto_free(BuildPanel.new()) as BuildPanel
	add_child(panel)
	return panel


func test_level_picker_hidden_without_project() -> void:
	var panel := _make_panel()
	await get_tree().process_frame

	assert_bool(panel._level_picker.visible).is_false()
	assert_bool(panel._add_level_button.visible).is_false()


func test_level_picker_lists_project_levels_and_selects_current() -> void:
	var created: Dictionary = ProjectStore.create_project("Picker")
	ProjectStore.load_project(created.slug)
	ProjectStore.add_level()
	ProjectStore.set_current_level(1)

	var panel := _make_panel()
	await get_tree().process_frame

	assert_bool(panel._level_picker.visible).is_true()
	assert_bool(panel._add_level_button.visible).is_true()
	assert_int(panel._level_picker.item_count).is_equal(2)
	assert_int(panel._level_picker.selected).is_equal(1)


func test_refresh_level_picker_tracks_added_levels() -> void:
	var created: Dictionary = ProjectStore.create_project("Tracker")
	ProjectStore.load_project(created.slug)

	var panel := _make_panel()
	await get_tree().process_frame
	assert_int(panel._level_picker.item_count).is_equal(1)

	ProjectStore.add_level()
	panel._refresh_level_picker()

	assert_int(panel._level_picker.item_count).is_equal(2)
