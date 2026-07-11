class_name TileLayerCatalog
extends RefCounted

## Discovers paintable TileMapLayer nodes in the active level scene.


static func discover(scene: Node) -> Array[Dictionary]:
	var layers: Array[Dictionary] = []
	if scene == null:
		return layers
	for node in scene.find_children("*", "TileMapLayer", true, false):
		var layer := node as TileMapLayer
		if layer == null:
			continue
		layers.append({
			"name": layer.name,
			"node_name": layer.name,
		})
	layers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.name) < String(b.name)
	)
	return layers
