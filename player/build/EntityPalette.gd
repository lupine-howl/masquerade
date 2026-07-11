class_name EntityPalette
extends RefCounted

## Builds a scene-placement palette from legacy spawn_scene tile bindings.
## Thumbnails come from atlas tiles; placement instantiates the bound scene.

const CATALOG_TILESETS: Array[String] = [
	"res://resources/tilesets/tileset_enemies.tres",
	"res://resources/tilesets/tileset_controls.tres",
]

const CATEGORIES: Array[String] = [
	"All", "Enemies", "Platforms", "Collectibles", "Hazards", "Triggers",
]


static func load_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var seen_paths: Dictionary = {}

	for tileset_path in CATALOG_TILESETS:
		if not ResourceLoader.exists(tileset_path):
			continue
		var tileset := ResourceLoader.load(tileset_path) as TileSet
		if tileset == null:
			continue
		for source_index in tileset.get_source_count():
			var source_id := tileset.get_source_id(source_index)
			var source := tileset.get_source(source_id)
			var atlas := source as TileSetAtlasSource
			if atlas == null:
				continue
			for tile_index in atlas.get_tiles_count():
				var coords := atlas.get_tile_id(tile_index)
				var tile_data := atlas.get_tile_data(coords, 0)
				if tile_data == null:
					continue
				var scene: PackedScene = tile_data.get_custom_data("spawn_scene") as PackedScene
				if scene == null:
					continue
				var scene_path: String = scene.resource_path
				if scene_path.is_empty() or seen_paths.has(scene_path):
					continue
				seen_paths[scene_path] = true
				var region := atlas.get_tile_texture_region(coords, 0)
				if region.size.x <= 0 or region.size.y <= 0:
					continue
				var thumb := AtlasTexture.new()
				thumb.atlas = atlas.texture
				thumb.region = region
				entries.append({
					"scene": scene,
					"texture": thumb,
					"label": scene_path.get_file().get_basename(),
					"category": _category_from_path(scene_path),
				})

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.label) < String(b.label)
	)
	return entries


static func _category_from_path(path: String) -> String:
	if path.contains("/enemies/"):
		return "Enemies"
	if path.contains("/platforms/"):
		return "Platforms"
	if path.contains("/collectibles/"):
		return "Collectibles"
	if path.contains("/hazards/"):
		return "Hazards"
	if path.contains("/triggers/"):
		return "Triggers"
	return "Other"
