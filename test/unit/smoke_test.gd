# GdUnit4 harness smoke test — proves the runner discovers and executes suites.

extends GdUnitTestSuite


func test_harness_runs() -> void:
	assert_bool(true).is_true()


func test_project_name() -> void:
	assert_str(ProjectSettings.get_setting("application/config/name")).is_equal("Masquerade")
