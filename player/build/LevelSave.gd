class_name LevelSave
extends RefCounted

## Tracks unsaved level edits and persists the current scene to disk.

static var dirty: bool = false


static func mark_dirty() -> void:
	dirty = true


static func clear_dirty() -> void:
	dirty = false


static func save_level(tree: SceneTree) -> Dictionary:
	var scene := tree.current_scene
	if scene == null:
		return {"ok": false, "error": "No active level"}
	var path: String = scene.scene_file_path
	if path.is_empty():
		return {"ok": false, "error": "Level has no save path (scene_file_path is empty)"}
	var packed := PackedScene.new()
	var pack_err: Error = packed.pack(scene)
	if pack_err != OK:
		return {"ok": false, "error": "Pack failed: %s" % error_string(pack_err)}
	var err: Error = ResourceSaver.save(packed, path)
	if err != OK:
		return {"ok": false, "error": "Save failed: %s" % error_string(err)}
	dirty = false
	_touch_project(tree, path)
	return {"ok": true, "path": path}


## Bumps the open project's modified timestamp when the saved level is one
## of its level files. Resolved via the tree so static context stays testable.
static func _touch_project(tree: SceneTree, saved_path: String) -> void:
	var store: Node = tree.root.get_node_or_null("ProjectStore")
	if store == null or not store.has_project():
		return
	if saved_path.begins_with(store.project_dir(String(store.current.slug))):
		store.save_project()
