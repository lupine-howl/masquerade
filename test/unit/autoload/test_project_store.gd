# Unit tests for scripts/autoload/ProjectStore.gd (autoload singleton).

extends GdUnitTestSuite


const TEST_ROOT := "user://tmp/project_store_test"

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


func _wipe_test_root() -> void:
	if DirAccess.dir_exists_absolute(TEST_ROOT):
		ProjectStore._remove_recursive(TEST_ROOT)


func test_create_project_writes_manifest_and_levels() -> void:
	var result: Dictionary = ProjectStore.create_project("My First Game")

	assert_bool(result.ok).is_true()
	assert_str(result.slug).is_equal("my-first-game")
	var dir := ProjectStore.project_dir("my-first-game")
	assert_bool(FileAccess.file_exists(dir.path_join("project.cfg"))).is_true()
	assert_bool(FileAccess.file_exists(dir.path_join("levels/level_1.tscn"))).is_true()


func test_create_project_rejects_empty_name() -> void:
	var result: Dictionary = ProjectStore.create_project("   ")
	assert_bool(result.ok).is_false()
	assert_str(result.error).contains("empty")


func test_create_project_rejects_unknown_template() -> void:
	var result: Dictionary = ProjectStore.create_project("Game", "no-such-template")
	assert_bool(result.ok).is_false()
	assert_str(result.error).contains("no-such-template")


func test_slug_collision_appends_counter() -> void:
	var first: Dictionary = ProjectStore.create_project("My Game")
	var second: Dictionary = ProjectStore.create_project("My Game")
	var third: Dictionary = ProjectStore.create_project("My Game")

	assert_str(first.slug).is_equal("my-game")
	assert_str(second.slug).is_equal("my-game-2")
	assert_str(third.slug).is_equal("my-game-3")


func test_slugify_strips_symbols() -> void:
	var result: Dictionary = ProjectStore.create_project("  Sky High!! (v2)  ")
	assert_bool(result.ok).is_true()
	assert_str(result.slug).is_equal("sky-high-v2")


func test_load_project_round_trip() -> void:
	var created: Dictionary = ProjectStore.create_project("Round Trip")

	var loaded: Dictionary = ProjectStore.load_project(created.slug)

	assert_bool(loaded.ok).is_true()
	assert_bool(ProjectStore.has_project()).is_true()
	assert_str(ProjectStore.current.name).is_equal("Round Trip")
	assert_int(ProjectStore.current.schema_version).is_equal(ProjectStore.SCHEMA_VERSION)
	assert_int(ProjectStore.current.current_level).is_equal(0)
	assert_array(Array(ProjectStore.current.levels)).contains_exactly(["level_1.tscn"])


func test_load_missing_project_fails() -> void:
	var result: Dictionary = ProjectStore.load_project("does-not-exist")
	assert_bool(result.ok).is_false()
	assert_bool(ProjectStore.has_project()).is_false()


func test_load_corrupt_manifest_fails() -> void:
	var dir := ProjectStore.project_dir("broken")
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(dir.path_join("project.cfg"), FileAccess.WRITE)
	file.store_string("this is not a config file [[[")
	file.close()

	var result: Dictionary = ProjectStore.load_project("broken")

	assert_bool(result.ok).is_false()


func test_list_projects_returns_created_projects() -> void:
	ProjectStore.create_project("Alpha")
	ProjectStore.create_project("Beta")

	var projects: Array[Dictionary] = ProjectStore.list_projects()

	assert_int(projects.size()).is_equal(2)
	var names: Array = projects.map(func(p: Dictionary) -> String: return String(p.name))
	assert_array(names).contains(["Alpha", "Beta"])


func test_list_projects_skips_invalid_directories() -> void:
	ProjectStore.create_project("Valid")
	DirAccess.make_dir_recursive_absolute(TEST_ROOT.path_join("junk-dir"))

	var projects: Array[Dictionary] = ProjectStore.list_projects()

	assert_int(projects.size()).is_equal(1)
	assert_str(projects[0].name).is_equal("Valid")


func test_save_project_persists_changes() -> void:
	var created: Dictionary = ProjectStore.create_project("Persist Me")
	ProjectStore.load_project(created.slug)
	ProjectStore.current.current_level = 3

	var saved: Dictionary = ProjectStore.save_project()
	assert_bool(saved.ok).is_true()

	ProjectStore.close_project()
	ProjectStore.load_project(created.slug)
	assert_int(ProjectStore.current.current_level).is_equal(3)


func test_save_project_fails_without_open_project() -> void:
	var result: Dictionary = ProjectStore.save_project()
	assert_bool(result.ok).is_false()


func test_delete_project_removes_directory_and_closes() -> void:
	var created: Dictionary = ProjectStore.create_project("Doomed")
	ProjectStore.load_project(created.slug)

	var result: Dictionary = ProjectStore.delete_project(created.slug)

	assert_bool(result.ok).is_true()
	assert_bool(DirAccess.dir_exists_absolute(ProjectStore.project_dir(created.slug))).is_false()
	assert_bool(ProjectStore.has_project()).is_false()
	assert_int(ProjectStore.list_projects().size()).is_equal(0)


func test_delete_missing_project_fails() -> void:
	var result: Dictionary = ProjectStore.delete_project("ghost")
	assert_bool(result.ok).is_false()


func test_get_level_path_resolves_and_bounds_checks() -> void:
	var created: Dictionary = ProjectStore.create_project("Paths")
	ProjectStore.load_project(created.slug)

	var path := ProjectStore.get_level_path(0)
	assert_str(path).contains("levels/level_1.tscn")
	assert_bool(FileAccess.file_exists(path)).is_true()
	assert_str(ProjectStore.get_level_path(1)).is_equal("")
	assert_str(ProjectStore.get_level_path(-1)).is_equal("")


func test_get_level_path_empty_without_project() -> void:
	assert_str(ProjectStore.get_level_path(0)).is_equal("")


func test_template_rules_propagate_to_project() -> void:
	var created: Dictionary = ProjectStore.create_project("Ruled")
	ProjectStore.load_project(created.slug)

	assert_float(ProjectStore.get_rule("max_hp")).is_equal(80.0)
	assert_float(ProjectStore.get_rule("starting_hp")).is_equal(80.0)
	assert_int(ProjectStore.get_rule("keys_to_exit")).is_equal(1)


func test_get_rule_defaults_without_project() -> void:
	assert_str(String(ProjectStore.get_rule("max_hp", "fallback"))).is_equal("fallback")


func test_template_recorded_in_manifest() -> void:
	var created: Dictionary = ProjectStore.create_project("Templated")
	ProjectStore.load_project(created.slug)
	assert_str(ProjectStore.current.template).is_equal("platformer")


func test_add_level_appends_and_persists() -> void:
	var created: Dictionary = ProjectStore.create_project("Grower")
	ProjectStore.load_project(created.slug)

	var result: Dictionary = ProjectStore.add_level()

	assert_bool(result.ok).is_true()
	assert_int(result.index).is_equal(1)
	assert_bool(FileAccess.file_exists(String(result.path))).is_true()

	ProjectStore.close_project()
	ProjectStore.load_project(created.slug)
	assert_array(Array(ProjectStore.current.levels)).contains_exactly(
		["level_1.tscn", "level_2.tscn"]
	)


func test_add_level_fails_without_project() -> void:
	var result: Dictionary = ProjectStore.add_level()
	assert_bool(result.ok).is_false()


func test_added_level_uses_blank_scene_and_loads() -> void:
	var created: Dictionary = ProjectStore.create_project("Blank Check")
	ProjectStore.load_project(created.slug)
	var result: Dictionary = ProjectStore.add_level()

	var packed := ResourceLoader.load(String(result.path)) as PackedScene
	assert_object(packed).is_not_null()
	var level := packed.instantiate()
	assert_object(level.get_node_or_null("Terrain")).is_not_null()
	assert_object(level.get_node_or_null("Enemies")).is_not_null()
	assert_object(level.get_node_or_null("Player")).is_not_null()
	level.free()


func test_set_current_level_persists_and_bounds_checks() -> void:
	var created: Dictionary = ProjectStore.create_project("Switcher")
	ProjectStore.load_project(created.slug)
	ProjectStore.add_level()

	assert_bool(ProjectStore.set_current_level(1).ok).is_true()
	assert_bool(ProjectStore.set_current_level(5).ok).is_false()
	assert_bool(ProjectStore.set_current_level(-1).ok).is_false()

	ProjectStore.close_project()
	ProjectStore.load_project(created.slug)
	assert_int(ProjectStore.current.current_level).is_equal(1)


func test_advance_level_progresses_then_completes() -> void:
	var created: Dictionary = ProjectStore.create_project("Journey")
	ProjectStore.load_project(created.slug)
	ProjectStore.add_level()

	var first: Dictionary = ProjectStore.advance_level()
	assert_str(first.action).is_equal("next_level")
	assert_int(first.index).is_equal(1)
	assert_bool(FileAccess.file_exists(String(first.path))).is_true()

	var second: Dictionary = ProjectStore.advance_level()
	assert_str(second.action).is_equal("completed")

	ProjectStore.close_project()
	ProjectStore.load_project(created.slug)
	assert_int(ProjectStore.current.current_level).is_equal(0)


func test_advance_level_without_project() -> void:
	var result: Dictionary = ProjectStore.advance_level()
	assert_str(result.action).is_equal("no_project")


func test_list_templates_includes_platformer() -> void:
	var templates: Array[Dictionary] = ProjectStore.list_templates()

	assert_array(templates).is_not_empty()
	var ids: Array = templates.map(func(t: Dictionary) -> String: return String(t.id))
	assert_array(ids).contains(["platformer"])


func test_copied_level_is_independent_of_template() -> void:
	var created: Dictionary = ProjectStore.create_project("Fork")
	ProjectStore.load_project(created.slug)
	var level_path := ProjectStore.get_level_path(0)

	var file := FileAccess.open(level_path, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string("\n; user edit marker\n")
	file.close()

	var template_source := FileAccess.open("res://levels/test.tscn", FileAccess.READ)
	var template_text := template_source.get_as_text()
	template_source.close()
	assert_bool(template_text.contains("user edit marker")).is_false()
