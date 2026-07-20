# Integration tests for player/build/LevelAuthoring.gd

extends GdUnitTestSuite


var _level: Node2D
var _enemies: Node2D
var _entity: Node2D
var _child: Node2D
var _marker: Node2D
var _previous_scene: Node


func before_test() -> void:
	var tree := get_tree()
	_previous_scene = tree.current_scene

	_level = Node2D.new()
	_level.name = "AuthoringLevel"
	_enemies = Node2D.new()
	_enemies.name = "Enemies"
	_entity = Node2D.new()
	_entity.name = "FakeEnemy"
	_child = Node2D.new()
	_child.name = "EnemyChild"
	_marker = Node2D.new()
	_marker.name = "NavMarker"
	_marker.add_to_group("navigation_markers")
	_marker.visible = true

	_entity.add_child(_child)
	_enemies.add_child(_entity)
	_level.add_child(_enemies)
	_level.add_child(_marker)
	tree.root.add_child(_level)
	tree.current_scene = _level


func after_test() -> void:
	var tree := get_tree()
	tree.current_scene = _previous_scene
	if is_instance_valid(_level):
		_level.free()


func test_build_tab_freezes_entities_and_shows_markers() -> void:
	_entity.process_mode = Node.PROCESS_MODE_INHERIT
	_child.process_mode = Node.PROCESS_MODE_INHERIT
	_marker.visible = false

	LevelAuthoring.apply_studio_tab(StudioTabBar.Tab.BUILD, get_tree())

	assert_int(int(_entity.process_mode)).is_equal(int(Node.PROCESS_MODE_DISABLED))
	assert_int(int(_child.process_mode)).is_equal(int(Node.PROCESS_MODE_DISABLED))
	assert_bool(_marker.visible).is_true()


func test_skin_and_animate_tabs_freeze_entities() -> void:
	for tab in [StudioTabBar.Tab.SKIN, StudioTabBar.Tab.ANIMATE]:
		_entity.process_mode = Node.PROCESS_MODE_INHERIT
		LevelAuthoring.apply_studio_tab(tab, get_tree())
		assert_int(int(_entity.process_mode)).is_equal(int(Node.PROCESS_MODE_DISABLED))
		assert_bool(_marker.visible).is_true()


func test_play_tab_activates_entities_and_hides_markers() -> void:
	_entity.process_mode = Node.PROCESS_MODE_DISABLED
	_child.process_mode = Node.PROCESS_MODE_DISABLED
	_marker.visible = true

	LevelAuthoring.apply_studio_tab(StudioTabBar.Tab.PLAY, get_tree())

	assert_int(int(_entity.process_mode)).is_equal(int(Node.PROCESS_MODE_INHERIT))
	assert_int(int(_child.process_mode)).is_equal(int(Node.PROCESS_MODE_INHERIT))
	assert_bool(_marker.visible).is_false()


func test_apply_studio_tab_noop_without_enemies_container() -> void:
	_enemies.name = "NotEnemies"
	_entity.process_mode = Node.PROCESS_MODE_INHERIT

	LevelAuthoring.apply_studio_tab(StudioTabBar.Tab.BUILD, get_tree())

	assert_int(int(_entity.process_mode)).is_equal(int(Node.PROCESS_MODE_INHERIT))
	assert_bool(_marker.visible).is_true()
	_enemies.name = "Enemies"


func test_prepare_placed_entity_disables_processing() -> void:
	var fresh := Node2D.new()
	var nested := Node2D.new()
	fresh.add_child(nested)
	fresh.process_mode = Node.PROCESS_MODE_INHERIT
	nested.process_mode = Node.PROCESS_MODE_INHERIT

	LevelAuthoring.prepare_placed_entity(fresh, true)

	assert_int(int(fresh.process_mode)).is_equal(int(Node.PROCESS_MODE_DISABLED))
	assert_int(int(nested.process_mode)).is_equal(int(Node.PROCESS_MODE_DISABLED))
	fresh.free()
