class_name LevelAuthoring
extends RefCounted

## Gates level entity simulation and navigation-marker visibility by studio tab.


static func apply_studio_tab(tab: StudioTabBar.Tab, tree: SceneTree) -> void:
	var playing := tab == StudioTabBar.Tab.PLAY
	var authoring := tab == StudioTabBar.Tab.BUILD
	_set_navigation_markers_visible(tree, authoring)
	_set_entities_active(tree, playing)


static func prepare_placed_entity(entity: Node) -> void:
	_set_process_mode_recursive(entity, Node.PROCESS_MODE_DISABLED)


static func _set_navigation_markers_visible(tree: SceneTree, visible: bool) -> void:
	for node in tree.get_nodes_in_group("navigation_markers"):
		if not is_instance_valid(node) or not node is CanvasItem:
			continue
		var item := node as CanvasItem
		item.visible = visible
		if visible:
			item.modulate.a = 1.0


static func _set_entities_active(tree: SceneTree, active: bool) -> void:
	var scene := tree.current_scene
	if scene == null:
		return
	var container := scene.get_node_or_null("Enemies")
	if container == null:
		return
	var mode := Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	for child in container.get_children():
		if is_instance_valid(child):
			_set_process_mode_recursive(child, mode)


static func _set_process_mode_recursive(node: Node, mode: Node.ProcessMode) -> void:
	node.process_mode = mode
	for child in node.get_children():
		if is_instance_valid(child):
			_set_process_mode_recursive(child, mode)
