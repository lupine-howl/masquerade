# Integration tests for scenes/home/HomeScreen.gd (boot screen).

extends GdUnitTestSuite


const TEST_ROOT := "user://tmp/home_screen_test"

var _saved_root: String
var _home: HomeScreen


func before_test() -> void:
	_saved_root = ProjectStore.root_dir
	ProjectStore.root_dir = TEST_ROOT
	ProjectStore.close_project()
	_wipe_test_root()

	_home = (load("res://scenes/home/HomeScreen.tscn") as PackedScene).instantiate() as HomeScreen
	_home.open_on_create = false
	add_child(_home)
	await get_tree().process_frame


func after_test() -> void:
	if is_instance_valid(_home):
		_home.free()
	_wipe_test_root()
	ProjectStore.root_dir = _saved_root
	ProjectStore.close_project()


func _wipe_test_root() -> void:
	if DirAccess.dir_exists_absolute(TEST_ROOT):
		ProjectStore._remove_recursive(TEST_ROOT)


func _project_rows() -> Array:
	return _home._project_list.get_children().filter(
		func(row: Node) -> bool: return not row.is_queued_for_deletion()
	)


func test_empty_state_visible_without_projects() -> void:
	assert_bool(_home._empty_label.visible).is_true()
	assert_int(_project_rows().size()).is_equal(0)


func test_template_picker_lists_platformer() -> void:
	assert_int(_home._template_picker.item_count).is_greater_equal(1)
	assert_str(_home._selected_template_id()).is_equal("platformer")


func test_refresh_lists_seeded_project() -> void:
	ProjectStore.create_project("Seeded Game")

	_home.refresh()
	await get_tree().process_frame

	assert_bool(_home._empty_label.visible).is_false()
	var rows := _project_rows()
	assert_int(rows.size()).is_equal(1)
	var open_button := rows[0].get_child(0) as Button
	assert_str(open_button.text).contains("Seeded Game")


func test_create_flow_creates_project_and_refreshes() -> void:
	_home._name_edit.text = "Fresh Start"

	_home._on_create_pressed()
	await get_tree().process_frame

	var projects: Array[Dictionary] = ProjectStore.list_projects()
	assert_int(projects.size()).is_equal(1)
	assert_str(projects[0].name).is_equal("Fresh Start")
	assert_str(_home._status_label.text).is_equal("")
	assert_str(_home._name_edit.text).is_equal("")
	assert_int(_project_rows().size()).is_equal(1)


func test_create_flow_rejects_empty_name_with_status() -> void:
	_home._name_edit.text = "   "

	_home._on_create_pressed()

	assert_int(ProjectStore.list_projects().size()).is_equal(0)
	assert_str(_home._status_label.text).contains("empty")


func test_delete_confirmed_removes_project() -> void:
	var created: Dictionary = ProjectStore.create_project("Doomed")
	_home.refresh()
	await get_tree().process_frame

	_home._pending_delete_slug = String(created.slug)
	_home._on_delete_confirmed()
	await get_tree().process_frame

	assert_int(ProjectStore.list_projects().size()).is_equal(0)
	assert_bool(_home._empty_label.visible).is_true()


func test_open_project_reports_error_for_missing_project() -> void:
	var result: Dictionary = _home.open_project("no-such-slug")

	assert_bool(result.ok).is_false()
	assert_str(_home._status_label.text).is_not_empty()


func test_created_project_level_is_loadable() -> void:
	var created: Dictionary = ProjectStore.create_project("Loadable")
	ProjectStore.load_project(created.slug)

	var level_path: String = ProjectStore.get_level_path(0)
	var packed := ResourceLoader.load(level_path) as PackedScene

	assert_object(packed).is_not_null()
	var node := packed.instantiate()
	assert_object(node).is_not_null()
	node.free()
