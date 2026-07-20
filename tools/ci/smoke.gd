extends SceneTree

## Headless CI smoke runner: import project globals, load main scene, run briefly.

const MAIN_SCENE := "res://levels/test.tscn"
const SMOKE_FRAMES := 120


func _initialize() -> void:
	var scene_err: Error = change_scene_to_file(MAIN_SCENE)
	if scene_err != OK:
		push_error("CI smoke: failed to load %s (%s)" % [MAIN_SCENE, error_string(scene_err)])
		quit(1)
		return
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	for _i in SMOKE_FRAMES:
		await process_frame
	quit(0)
