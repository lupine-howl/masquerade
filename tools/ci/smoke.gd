extends SceneTree

## Headless CI smoke runner: load the home screen (main scene), then the
## template level, running each briefly to catch load/startup breakage.

const HOME_SCENE := "res://scenes/home/HomeScreen.tscn"
const LEVEL_SCENE := "res://levels/test.tscn"
const SMOKE_FRAMES := 120


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	for scene_path in [HOME_SCENE, LEVEL_SCENE]:
		var scene_err: Error = change_scene_to_file(scene_path)
		if scene_err != OK:
			push_error("CI smoke: failed to load %s (%s)" % [scene_path, error_string(scene_err)])
			quit(1)
			return
		for _i in SMOKE_FRAMES:
			await process_frame
	quit(0)
