# Unit tests for player/build/TileLayerCatalog.gd

extends GdUnitTestSuite


func test_discover_null_scene_returns_empty() -> void:
	var layers: Array[Dictionary] = TileLayerCatalog.discover(null)
	assert_array(layers).is_empty()


func test_discover_finds_tile_map_layers() -> void:
	var root := Node2D.new()
	root.name = "Level"
	var terrain := TileMapLayer.new()
	terrain.name = "Terrain"
	var water := TileMapLayer.new()
	water.name = "Water"
	var deco := Node2D.new()
	deco.name = "Decoration"
	root.add_child(terrain)
	root.add_child(water)
	root.add_child(deco)
	add_child(root)

	var layers: Array[Dictionary] = TileLayerCatalog.discover(root)

	root.queue_free()
	assert_int(layers.size()).is_equal(2)
	assert_str(layers[0].name).is_equal("Terrain")
	assert_str(layers[1].name).is_equal("Water")
	assert_str(layers[0].node_name).is_equal("Terrain")


func test_discover_sorts_layer_names() -> void:
	var root := Node2D.new()
	var zebra := TileMapLayer.new()
	zebra.name = "Zebra"
	var alpha := TileMapLayer.new()
	alpha.name = "Alpha"
	var mid := TileMapLayer.new()
	mid.name = "Mid"
	root.add_child(zebra)
	root.add_child(alpha)
	root.add_child(mid)
	add_child(root)

	var layers: Array[Dictionary] = TileLayerCatalog.discover(root)

	root.queue_free()
	assert_array([layers[0].name, layers[1].name, layers[2].name]).contains_exactly(
		["Alpha", "Mid", "Zebra"]
	)


func test_discover_finds_nested_layers() -> void:
	var root := Node2D.new()
	var wrapper := Node2D.new()
	wrapper.name = "Wrapper"
	var nested := TileMapLayer.new()
	nested.name = "NestedTerrain"
	wrapper.add_child(nested)
	root.add_child(wrapper)
	add_child(root)

	var layers: Array[Dictionary] = TileLayerCatalog.discover(root)

	root.queue_free()
	assert_int(layers.size()).is_equal(1)
	assert_str(layers[0].name).is_equal("NestedTerrain")
