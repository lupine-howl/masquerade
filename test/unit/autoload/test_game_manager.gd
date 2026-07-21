# Unit tests for scripts/autoload/GameManager.gd (autoload singleton).

extends GdUnitTestSuite


func before_test() -> void:
	_reset_game_manager()


func after_test() -> void:
	_reset_game_manager()
	for node in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(node) and node.get_parent() == get_tree().root:
			node.free()


func _reset_game_manager() -> void:
	GameManager.points = 0
	GameManager.keys = 0
	GameManager.max_hp = 80.0
	GameManager.current_hp = 80.0
	GameManager.last_checkpoint_position = Vector2.ZERO


func test_add_point_increments_and_emits() -> void:
	var received: Array = []
	GameManager.points_changed.connect(func(value: int) -> void: received.append(value))

	GameManager.add_point()
	GameManager.add_point()

	assert_int(GameManager.points).is_equal(2)
	assert_array(received).contains_exactly([1, 2])


func test_add_key_increments_and_emits() -> void:
	var received: Array = []
	GameManager.keys_changed.connect(func(value: int) -> void: received.append(value))

	GameManager.add_key()

	assert_int(GameManager.keys).is_equal(1)
	assert_array(received).contains_exactly([1])


func test_add_health_clamps_to_max_hp() -> void:
	var received: Array = []
	GameManager.hp_changed.connect(func(value: float) -> void: received.append(value))
	GameManager.current_hp = 70.0

	GameManager.add_health(50.0)

	assert_float(GameManager.current_hp).is_equal(80.0)
	assert_array(received).contains_exactly([80.0])


func test_add_health_below_max_increases() -> void:
	GameManager.current_hp = 40.0
	GameManager.add_health(10.0)
	assert_float(GameManager.current_hp).is_equal(50.0)


func test_take_damage_reduces_hp_and_emits() -> void:
	var received: Array = []
	GameManager.hp_changed.connect(func(value: float) -> void: received.append(value))

	GameManager.take_damage(20.0)

	assert_float(GameManager.current_hp).is_equal(60.0)
	assert_array(received).contains_exactly([60.0])


func test_take_damage_clamps_at_zero() -> void:
	GameManager.take_damage(999.0)
	assert_float(GameManager.current_hp).is_equal(0.0)


func test_reset_health_restores_hp_and_clears_keys() -> void:
	var hp_received: Array = []
	var key_received: Array = []
	GameManager.hp_changed.connect(func(value: float) -> void: hp_received.append(value))
	GameManager.keys_changed.connect(func(value: int) -> void: key_received.append(value))

	GameManager.current_hp = 10.0
	GameManager.keys = 3
	GameManager.reset_health()

	assert_float(GameManager.current_hp).is_equal(80.0)
	assert_int(GameManager.keys).is_equal(0)
	assert_array(hp_received).contains_exactly([80.0])
	assert_array(key_received).contains_exactly([0])


func test_start_session_applies_rules_and_resets() -> void:
	GameManager.points = 7
	GameManager.keys = 2
	GameManager.last_checkpoint_position = Vector2(9, 9)
	var points_received: Array = []
	var keys_received: Array = []
	var hp_received: Array = []
	GameManager.points_changed.connect(func(v: int) -> void: points_received.append(v))
	GameManager.keys_changed.connect(func(v: int) -> void: keys_received.append(v))
	GameManager.hp_changed.connect(func(v: float) -> void: hp_received.append(v))

	GameManager.start_session({"max_hp": 120.0, "starting_hp": 100.0, "keys_to_exit": 3})

	assert_float(GameManager.max_hp).is_equal(120.0)
	assert_float(GameManager.current_hp).is_equal(100.0)
	assert_int(GameManager.points).is_equal(0)
	assert_int(GameManager.keys).is_equal(0)
	assert_vector(GameManager.last_checkpoint_position).is_equal(Vector2.ZERO)
	assert_array(points_received).contains_exactly([0])
	assert_array(keys_received).contains_exactly([0])
	assert_array(hp_received).contains_exactly([100.0])


func test_start_session_defaults_without_rules() -> void:
	GameManager.max_hp = 200.0
	GameManager.current_hp = 5.0

	GameManager.start_session()

	assert_float(GameManager.max_hp).is_equal(80.0)
	assert_float(GameManager.current_hp).is_equal(80.0)


func test_start_session_clamps_starting_hp_to_max() -> void:
	GameManager.start_session({"max_hp": 50.0, "starting_hp": 90.0})

	assert_float(GameManager.max_hp).is_equal(50.0)
	assert_float(GameManager.current_hp).is_equal(50.0)


func test_start_session_rules_drive_damage_and_heal_clamps() -> void:
	GameManager.start_session({"max_hp": 30.0, "starting_hp": 30.0})

	GameManager.take_damage(10.0)
	assert_float(GameManager.current_hp).is_equal(20.0)
	GameManager.add_health(50.0)
	assert_float(GameManager.current_hp).is_equal(30.0)


func test_start_level_clears_keys_and_checkpoint_keeps_points_and_hp() -> void:
	GameManager.start_session()
	GameManager.add_point()
	GameManager.add_key()
	GameManager.take_damage(15.0)
	GameManager.last_checkpoint_position = Vector2(64, 64)
	var keys_received: Array = []
	GameManager.keys_changed.connect(func(v: int) -> void: keys_received.append(v))

	GameManager.start_level()

	assert_int(GameManager.keys).is_equal(0)
	assert_vector(GameManager.last_checkpoint_position).is_equal(Vector2.ZERO)
	assert_int(GameManager.points).is_equal(1)
	assert_float(GameManager.current_hp).is_equal(65.0)
	assert_array(keys_received).contains_exactly([0])


func test_trigger_player_respawn_moves_player_to_checkpoint() -> void:
	var player := Node2D.new()
	player.name = "TestPlayer"
	player.add_to_group("player")
	get_tree().root.add_child(player)
	player.global_position = Vector2(12, 34)

	var checkpoint := Vector2(256, 128)
	GameManager.last_checkpoint_position = checkpoint
	GameManager.current_hp = 0.0

	var hp_received: Array = []
	GameManager.hp_changed.connect(func(value: float) -> void: hp_received.append(value))

	GameManager.trigger_player_respawn()

	assert_float(GameManager.current_hp).is_equal(80.0)
	assert_array(hp_received).contains_exactly([80.0])
	assert_vector(player.global_position).is_equal(checkpoint)

	player.free()
