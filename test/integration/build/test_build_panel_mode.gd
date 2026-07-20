# Integration tests for BuildPanel mode state transitions.

extends GdUnitTestSuite


func test_paint_enabled_false_clears_selection_state() -> void:
	var panel := auto_free(BuildPanel.new()) as BuildPanel
	add_child(panel)
	await get_tree().process_frame

	panel.paint_enabled = true
	assert_bool(panel.paint_enabled).is_true()

	panel.paint_enabled = false
	assert_bool(panel.paint_enabled).is_false()


func test_pose_hud_build_play_toggles_paint_enabled() -> void:
	var runner := scene_runner("res://player/player.tscn")
	await runner.simulate_frames(2)
	var root: Node = runner.scene()
	assert_object(root).is_not_null()
	var hud: PoseHUD = root.get_node("PoseHUD")

	hud._commit_studio_tab(StudioTabBar.Tab.BUILD)
	assert_bool(hud.build_panel.paint_enabled).is_true()
	assert_bool(hud.build_panel.visible).is_true()

	hud._commit_studio_tab(StudioTabBar.Tab.PLAY)
	assert_bool(hud.build_panel.paint_enabled).is_false()
	assert_bool(hud.build_panel.visible).is_false()

	hud._commit_studio_tab(StudioTabBar.Tab.BUILD)
	assert_bool(hud.build_panel.paint_enabled).is_true()
	assert_bool(hud.build_panel.visible).is_true()
