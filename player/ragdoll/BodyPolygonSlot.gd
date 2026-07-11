class_name BodyPolygonSlot
extends Polygon2D

## Skinned body polygon bound to Armature/Skeleton2D.
## Use offset for placement — avoid moving this node with transform (pivot issues).
## Shape, UVs, internal vertices, and weight painting: Polygon2D UV editor.

@export var skeleton_root: Skeleton2D


func _ready() -> void:
	_bind_skeleton()


func _bind_skeleton() -> void:
	if skeleton_root == null or not is_instance_valid(skeleton_root):
		if skeleton.is_empty():
			push_warning("BodyPolygonSlot '%s': assign skeleton_root or skeleton path." % name)
		return

	var path := get_path_to(skeleton_root)
	if skeleton != path:
		skeleton = path


func set_texture_from_path(path: String) -> bool:
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("BodyPolygonSlot: invalid texture path: %s" % path)
		return false
	var loaded_texture := load(path) as Texture2D
	if loaded_texture == null:
		push_warning("BodyPolygonSlot: failed to load texture: %s" % path)
		return false
	texture = loaded_texture
	return true
