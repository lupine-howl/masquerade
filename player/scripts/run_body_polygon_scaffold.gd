extends SceneTree

const PLAYER_SCENE := "res://player/player.tscn"
const BODY_POLYGONS_PATH := "PlayerBody/FacingPivot/Armature/BodyPolygons"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(PLAYER_SCENE) as PackedScene
	if packed == null:
		push_error("Failed to load player scene.")
		quit(1)
		return

	var player := packed.instantiate()
	root.add_child(player)
	await process_frame

	var body_polygons := player.get_node_or_null(BODY_POLYGONS_PATH)
	if body_polygons == null:
		push_error("BodyPolygons node not found.")
		quit(1)
		return

	if not body_polygons.has_method("scaffold_from_reference_sprites"):
		push_error("BodyPolygonsScaffold script not attached.")
		quit(1)
		return

	body_polygons.scaffold_from_reference_sprites()

	var err := packed.pack(player)
	if err != OK:
		push_error("pack() failed: %s" % err)
		quit(1)
		return

	err = ResourceSaver.save(packed, PLAYER_SCENE)
	if err != OK:
		push_error("save() failed: %s" % err)
		quit(1)
		return

	print("Saved scaffolded polygons to ", PLAYER_SCENE)
	quit()
