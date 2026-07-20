# Unit tests for player/build/EntityPalette.gd

extends GdUnitTestSuite


func test_category_from_path_enemies() -> void:
	assert_str(EntityPalette._category_from_path("res://scenes/enemies/enemy_bat.tscn")).is_equal(
		"Enemies"
	)


func test_category_from_path_platforms() -> void:
	assert_str(
		EntityPalette._category_from_path("res://scenes/platforms/moving_cloud_platform.tscn")
	).is_equal("Platforms")


func test_category_from_path_collectibles() -> void:
	assert_str(EntityPalette._category_from_path("res://scenes/collectibles/coin/coin.tscn")).is_equal(
		"Collectibles"
	)


func test_category_from_path_hazards() -> void:
	assert_str(EntityPalette._category_from_path("res://scenes/hazards/spikes/spikes_up.tscn")).is_equal(
		"Hazards"
	)


func test_category_from_path_triggers() -> void:
	assert_str(
		EntityPalette._category_from_path("res://scenes/environment/triggers/trigger_falling.tscn")
	).is_equal("Triggers")


func test_category_from_path_other() -> void:
	assert_str(EntityPalette._category_from_path("res://scenes/ui/ui.tscn")).is_equal("Other")


func test_load_entries_returns_unique_sorted_entries() -> void:
	var entries: Array[Dictionary] = EntityPalette.load_entries()
	assert_array(entries).is_not_empty()

	var seen_paths: Dictionary = {}
	var labels: PackedStringArray = PackedStringArray()
	for entry in entries:
		assert_dict(entry).contains_keys(["scene", "texture", "label", "category"])
		var scene: PackedScene = entry.scene
		assert_object(scene).is_not_null()
		var scene_path: String = scene.resource_path
		assert_str(scene_path).is_not_empty()
		assert_bool(seen_paths.has(scene_path)).is_false()
		seen_paths[scene_path] = true
		labels.append(String(entry.label))
		assert_str(entry.label).is_equal(scene_path.get_file().get_basename())
		assert_str(entry.category).is_not_equal("")
		assert_bool(
			entry.category in ["Enemies", "Platforms", "Collectibles", "Hazards", "Triggers", "Other"]
		).is_true()
		assert_object(entry.texture).is_not_null()

	var sorted_labels := labels.duplicate()
	sorted_labels.sort()
	assert_array(Array(labels)).contains_exactly(Array(sorted_labels))


func test_categories_constant_includes_all() -> void:
	assert_array(EntityPalette.CATEGORIES).contains(["All", "Enemies", "Platforms", "Collectibles", "Hazards", "Triggers"])
