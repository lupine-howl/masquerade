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
	return {"ok": true, "path": path}


static func prompt_unsaved(parent: Node) -> String:
	var dialog := AcceptDialog.new()
	dialog.title = "Unsaved level changes"
	dialog.dialog_text = "Save changes to the level before continuing?"
	dialog.ok_button_text = "Save"
	dialog.add_cancel_button("Cancel")
	dialog.add_button("Discard", false, "discard")
	parent.add_child(dialog)

	var choice := "cancel"
	var complete := func(value: String) -> void:
		choice = value
		dialog.hide()
	dialog.confirmed.connect(func() -> void: complete.call("save"))
	dialog.canceled.connect(func() -> void: complete.call("cancel"))
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action == "discard":
			complete.call("discard")
	)
	dialog.popup_centered()
	while dialog.visible:
		await parent.get_tree().process_frame
	dialog.queue_free()
	return choice
