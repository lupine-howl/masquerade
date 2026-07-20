# Integration tests for PoseHUD studio tab orchestration via player scene.

extends GdUnitTestSuite


var _runner: GdUnitSceneRunner
var _hud: PoseHUD
var _player: Player


func before_test() -> void:
	_runner = scene_runner("res://player/player.tscn")
	await _runner.simulate_frames(2)
	var root: Node = _runner.scene()
	assert_object(root).is_not_null()
	# Player.gd is on PlayerBody (CharacterBody2D); root is a plain Node2D shell.
	_player = root.get_node_or_null("PlayerBody") as Player
	assert_object(_player).is_not_null()
	_hud = root.get_node_or_null("PoseHUD") as PoseHUD
	assert_object(_hud).is_not_null()
	assert_object(_hud.part_panel).is_not_null()
	assert_object(_hud.timeline_panel).is_not_null()
	assert_object(_hud.build_panel).is_not_null()
	assert_object(_hud.play_stats_panel).is_not_null()


func test_skin_tab_shows_part_panel_and_enables_posing() -> void:
	_hud._commit_studio_tab(StudioTabBar.Tab.SKIN)

	assert_bool(_hud.part_panel.visible).is_true()
	assert_bool(_hud.timeline_panel.visible).is_false()
	assert_bool(_hud.build_panel.visible).is_false()
	assert_bool(_hud.play_stats_panel.visible).is_false()
	assert_bool(_hud.build_panel.paint_enabled).is_false()
	assert_bool(_player.is_posing).is_true()
	assert_int(int(_hud.get_studio_tab())).is_equal(int(StudioTabBar.Tab.SKIN))


func test_animate_tab_shows_timeline_and_enables_posing() -> void:
	_hud._commit_studio_tab(StudioTabBar.Tab.ANIMATE)

	assert_bool(_hud.part_panel.visible).is_false()
	assert_bool(_hud.timeline_panel.visible).is_true()
	assert_bool(_hud.build_panel.visible).is_false()
	assert_bool(_hud.play_stats_panel.visible).is_false()
	assert_bool(_hud.build_panel.paint_enabled).is_false()
	assert_bool(_player.is_posing).is_true()


func test_build_tab_shows_build_panel_and_enables_paint() -> void:
	_hud._commit_studio_tab(StudioTabBar.Tab.BUILD)

	assert_bool(_hud.part_panel.visible).is_false()
	assert_bool(_hud.timeline_panel.visible).is_false()
	assert_bool(_hud.build_panel.visible).is_true()
	assert_bool(_hud.play_stats_panel.visible).is_false()
	assert_bool(_hud.build_panel.paint_enabled).is_true()
	assert_bool(_player.is_posing).is_false()


func test_play_tab_shows_stats_and_disables_authoring() -> void:
	_hud._commit_studio_tab(StudioTabBar.Tab.BUILD)
	_hud._commit_studio_tab(StudioTabBar.Tab.PLAY)

	assert_bool(_hud.part_panel.visible).is_false()
	assert_bool(_hud.timeline_panel.visible).is_false()
	assert_bool(_hud.build_panel.visible).is_false()
	assert_bool(_hud.play_stats_panel.visible).is_true()
	assert_bool(_hud.build_panel.paint_enabled).is_false()
	assert_bool(_player.is_posing).is_false()
	assert_int(int(_hud.get_studio_tab())).is_equal(int(StudioTabBar.Tab.PLAY))


func test_legacy_toolbar_stays_hidden() -> void:
	var toolbar := _hud.get_node_or_null("PoseToolBar")
	assert_object(toolbar).is_not_null()
	assert_bool(toolbar.visible).is_false()

	_hud._commit_studio_tab(StudioTabBar.Tab.SKIN)
	_hud._commit_studio_tab(StudioTabBar.Tab.BUILD)
	assert_bool(toolbar.visible).is_false()
