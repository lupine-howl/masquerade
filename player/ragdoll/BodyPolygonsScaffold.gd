@tool
extends Node2D

## Editor helper: fit BodyPolygons to skeleton reference sprites.
## Attach to Armature/BodyPolygons, then use the inspector checkbox below.

const _SINGLE_BONE_MAP: Dictionary = {
	"Head": {
		"sprite": "Head_Sprite",
		"bone": "Pelvis/Abdomen/Torso/Shoulders/Neck/Head",
	},
	"Torso": {
		"sprite": "Torso",
		"bone": "Pelvis/Abdomen/Torso",
		"parent": "Torso",
	},
	"Jetpack": {
		"sprite": "Jetpack",
		"bone": "Pelvis/Abdomen/Torso",
		"parent": "Torso",
	},
	"UpperArm_Back": {
		"sprite": "UpperArm_Back_Sprite",
		"bone": "Pelvis/Abdomen/Torso/Shoulders/UpperArm_Back",
	},
	"Forearm_Back": {
		"sprite": "Forearm_Back_Sprite",
		"bone": "Pelvis/Abdomen/Torso/Shoulders/UpperArm_Back/Forearm_Back",
	},
	"Hand_Back": {
		"sprite": "Hand_Back_Sprite",
		"bone": "Pelvis/Abdomen/Torso/Shoulders/UpperArm_Back/Forearm_Back/Hand_Back",
	},
	"UpperArm_Front": {
		"sprite": "UpperArm_Front_Sprite",
		"bone": "Pelvis/Abdomen/Torso/Shoulders/UpperArm_Front",
	},
	"Forearm_Front": {
		"sprite": "Forearm_Front_Sprite",
		"bone": "Pelvis/Abdomen/Torso/Shoulders/UpperArm_Front/Forearm_Front",
	},
	"Hand_Front": {
		"sprite": "Hand_Front_Sprite",
		"bone": "Pelvis/Abdomen/Torso/Shoulders/UpperArm_Front/Forearm_Front/Hand_Front",
	},
	"Thigh_Back": {
		"sprite": "Thigh_Back_Sprite",
		"bone": "Pelvis/Thigh_Back",
	},
	"Calf_Back": {
		"sprite": "Calf_Back_Sprite",
		"bone": "Pelvis/Thigh_Back/Calf_Back",
	},
	"Foot_Back": {
		"sprite": "Foot_Sprite_Back",
		"bone": "Pelvis/Thigh_Back/Calf_Back/Foot_Back",
	},
	"Thigh_Front": {
		"sprite": "Thigh_Front_Sprite",
		"bone": "Pelvis/Thigh_Front",
	},
	"Calf_Front": {
		"sprite": "Calf_Front_Sprite",
		"bone": "Pelvis/Thigh_Front/Calf_Front",
	},
	"Foot_Front": {
		"sprite": "Foot_Sprite_Front",
		"bone": "Pelvis/Thigh_Front/Calf_Front/Foot_Front",
	},
}


@export_group("Polygon scaffold")
var _fit_polygons_to_skeleton_sprites: bool = false

## Check this box once to fit all child polygons to skeleton reference sprites.
@export var fit_polygons_to_skeleton_sprites: bool:
	set(value):
		_fit_polygons_to_skeleton_sprites = false
		if value and Engine.is_editor_hint():
			scaffold_from_reference_sprites()
	get:
		return _fit_polygons_to_skeleton_sprites


@export_tool_button("Fit polygons to skeleton sprites", "Callable")
var fit_polygons_tool_button: Callable:
	get:
		return Callable(self, &"scaffold_from_reference_sprites")


func scaffold_from_reference_sprites() -> void:
	var armature := get_parent()
	if armature == null:
		push_error("BodyPolygonsScaffold: expected parent Armature.")
		return
	var skeleton := armature.get_node_or_null("Skeleton2D") as Skeleton2D
	if skeleton == null:
		push_error("BodyPolygonsScaffold: Skeleton2D not found.")
		return

	for poly_name: String in _SINGLE_BONE_MAP:
		var entry: Dictionary = _SINGLE_BONE_MAP[poly_name]
		var poly_parent: Node = self
		if entry.has("parent"):
			poly_parent = get_node_or_null(String(entry.parent))
			if poly_parent == null:
				push_warning("BodyPolygonsScaffold: missing folder '%s'." % entry.parent)
				continue
		var poly := poly_parent.get_node_or_null(poly_name) as Polygon2D
		if poly == null:
			push_warning("BodyPolygonsScaffold: missing polygon '%s'." % poly_name)
			continue
		var sprite := _find_sprite_in_skeleton(skeleton, String(entry.sprite))
		if sprite == null:
			push_warning("BodyPolygonsScaffold: missing reference sprite '%s'." % entry.sprite)
			continue
		_apply_sprite_to_polygon(poly, sprite, skeleton, String(entry.bone))

	_scaffold_abdomen_seam(skeleton)

	print("BodyPolygonsScaffold: finished fitting polygons to skeleton sprites.")


func _scaffold_abdomen_seam(skeleton: Skeleton2D) -> void:
	var poly := get_node_or_null("AbdomenSeam") as Polygon2D
	if poly == null:
		return
	var lower := _find_sprite_in_skeleton(skeleton, "LowerAbdomen_Sprite")
	var upper := _find_sprite_in_skeleton(skeleton, "UpperAbdomen_Sprite2")
	if lower == null or upper == null:
		push_warning("BodyPolygonsScaffold: abdomen reference sprites not found.")
		return

	var lower_pts := _sprite_corners_in_space(lower, self)
	var upper_pts := _sprite_corners_in_space(upper, self)
	var merged := _merge_sprite_quads(lower_pts, upper_pts)
	poly.offset = Vector2.ZERO
	poly.rotation = 0.0
	poly.scale = Vector2.ONE
	poly.polygon = merged.polygon
	poly.uv = merged.uv
	poly.texture = lower.texture
	poly.skeleton = poly.get_path_to(skeleton)
	poly.bones = [
		"Pelvis", PackedFloat32Array([1.0, 1.0, 0.0, 0.0]),
		"Pelvis/Abdomen", PackedFloat32Array([0.0, 0.0, 1.0, 1.0]),
	]
	_copy_sprite_visuals(poly, lower)


func _apply_sprite_to_polygon(poly: Polygon2D, sprite: Sprite2D, skeleton: Skeleton2D, bone_path: String) -> void:
	var fit := _sprite_corners_in_space(sprite, self)
	poly.offset = Vector2.ZERO
	poly.rotation = 0.0
	poly.scale = Vector2.ONE
	poly.polygon = fit.polygon
	poly.uv = fit.uv
	poly.texture = sprite.texture
	poly.skeleton = poly.get_path_to(skeleton)
	poly.bones = [bone_path, PackedFloat32Array([1.0, 1.0, 1.0, 1.0])]
	_copy_sprite_visuals(poly, sprite)


func _copy_sprite_visuals(poly: Polygon2D, sprite: Sprite2D) -> void:
	poly.z_index = sprite.z_index
	poly.modulate = sprite.modulate
	poly.visible = sprite.visible


func _find_sprite_in_skeleton(skeleton: Skeleton2D, sprite_name: String) -> Sprite2D:
	var stack: Array[Node] = [skeleton]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			if child is Sprite2D and child.name == sprite_name:
				return child
			if child is Bone2D:
				stack.append(child)
	return null


func _sprite_corners_in_space(sprite: Sprite2D, space: Node2D) -> Dictionary:
	var to_space := space.get_global_transform().affine_inverse() * sprite.get_global_transform()
	var rect := sprite.get_rect()
	var local_corners := PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size,
		rect.position + Vector2(0.0, rect.size.y),
	])
	var polygon := PackedVector2Array()
	for corner in local_corners:
		polygon.append(to_space * corner)

	var region := sprite.region_rect
	var uv := PackedVector2Array([
		Vector2(region.position.x, region.end.y),
		Vector2(region.end.x, region.end.y),
		Vector2(region.end.x, region.position.y),
		Vector2(region.position.x, region.position.y),
	])
	return {"polygon": polygon, "uv": uv}


func _merge_sprite_quads(lower: Dictionary, upper: Dictionary) -> Dictionary:
	var lower_poly: PackedVector2Array = lower.polygon
	var upper_poly: PackedVector2Array = upper.polygon
	var lower_uv: PackedVector2Array = lower.uv
	var upper_uv: PackedVector2Array = upper.uv

	var lower_mid_y := (lower_poly[0].y + lower_poly[1].y) * 0.5
	var upper_mid_y := (upper_poly[2].y + upper_poly[3].y) * 0.5

	var merged_poly := PackedVector2Array([
		(lower_poly[0] + lower_poly[1]) * 0.5,
		(lower_poly[2] + lower_poly[3]) * 0.5,
		(upper_poly[2] + upper_poly[3]) * 0.5,
		(upper_poly[0] + upper_poly[1]) * 0.5,
	])
	# Keep a stable pelvis/abdomen split at the horizontal midline between pieces.
	merged_poly[0].y = lower_mid_y
	merged_poly[1].y = lower_mid_y
	merged_poly[2].y = upper_mid_y
	merged_poly[3].y = upper_mid_y

	var merged_uv := PackedVector2Array([
		(lower_uv[0] + lower_uv[1]) * 0.5,
		(lower_uv[2] + lower_uv[3]) * 0.5,
		(upper_uv[2] + upper_uv[3]) * 0.5,
		(upper_uv[0] + upper_uv[1]) * 0.5,
	])
	return {"polygon": merged_poly, "uv": merged_uv}
