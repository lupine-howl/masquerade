# Unit tests for player/build/LevelSave.gd

extends GdUnitTestSuite


func before_test() -> void:
	LevelSave.clear_dirty()


func after_test() -> void:
	LevelSave.clear_dirty()


func test_dirty_defaults_false_after_clear() -> void:
	LevelSave.mark_dirty()
	LevelSave.clear_dirty()
	assert_bool(LevelSave.dirty).is_false()


func test_mark_dirty_sets_flag() -> void:
	assert_bool(LevelSave.dirty).is_false()
	LevelSave.mark_dirty()
	assert_bool(LevelSave.dirty).is_true()


func test_save_level_fails_without_current_scene() -> void:
	var tree := get_tree()
	var previous: Node = tree.current_scene
	tree.current_scene = null

	var result: Dictionary = LevelSave.save_level(tree)

	tree.current_scene = previous
	assert_dict(result).contains_keys(["ok", "error"])
	assert_bool(result.ok).is_false()
	assert_str(result.error).is_equal("No active level")


func test_save_level_fails_when_scene_path_empty() -> void:
	var tree := get_tree()
	var previous: Node = tree.current_scene
	var orphan := Node2D.new()
	orphan.name = "UnsavedLevel"
	# current_scene must be a direct child of the scene tree root
	tree.root.add_child(orphan)
	tree.current_scene = orphan

	LevelSave.mark_dirty()
	var result: Dictionary = LevelSave.save_level(tree)

	tree.current_scene = previous
	orphan.free()
	assert_bool(result.ok).is_false()
	assert_str(result.error).contains("no save path")
	assert_bool(LevelSave.dirty).is_true()


func test_save_level_inside_project_bumps_modified_timestamp() -> void:
	var saved_root: String = ProjectStore.root_dir
	ProjectStore.root_dir = "user://tmp/level_save_project_test"
	var created: Dictionary = ProjectStore.create_project("Stamp")
	ProjectStore.load_project(created.slug)

	# Backdate the manifest so a bump is observable at second granularity.
	ProjectStore.current.modified_unix = 1000
	ProjectStore._write_manifest(ProjectStore.project_dir(created.slug), ProjectStore.current)

	var tree := get_tree()
	var previous: Node = tree.current_scene
	var level := Node2D.new()
	level.name = "ProjectLevel"
	level.scene_file_path = ProjectStore.get_level_path(0)
	tree.root.add_child(level)
	tree.current_scene = level

	var result: Dictionary = LevelSave.save_level(tree)

	tree.current_scene = previous
	level.free()
	assert_bool(result.ok).is_true()

	ProjectStore.close_project()
	ProjectStore.load_project(created.slug)
	assert_int(ProjectStore.current.modified_unix).is_greater(1000)

	ProjectStore._remove_recursive("user://tmp/level_save_project_test")
	ProjectStore.root_dir = saved_root
	ProjectStore.close_project()


func test_save_level_succeeds_and_clears_dirty() -> void:
	var tree := get_tree()
	var previous: Node = tree.current_scene
	var path := "user://ci_level_save_test.tscn"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	var level := Node2D.new()
	level.name = "SavedLevel"
	level.scene_file_path = path
	tree.root.add_child(level)
	tree.current_scene = level

	LevelSave.mark_dirty()
	var result: Dictionary = LevelSave.save_level(tree)

	tree.current_scene = previous
	level.free()
	assert_bool(result.ok).is_true()
	assert_str(result.path).is_equal(path)
	assert_bool(LevelSave.dirty).is_false()
	assert_bool(FileAccess.file_exists(path)).is_true()
	DirAccess.remove_absolute(path)
