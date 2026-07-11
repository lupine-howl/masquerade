class_name LevelAuthoring
extends RefCounted

## Gates level entity simulation and navigation-marker visibility by studio tab.


static func apply_studio_tab(tab: StudioTabBar.Tab, tree: SceneTree) -> void:
	var playing := tab == StudioTabBar.Tab.PLAY
	var authoring := tab == StudioTabBar.Tab.BUILD
	_set_navigation_markers_visible(tree, authoring)
	_set_entities_active(tree, playing)
	# Run again next frame so markers added/placed this frame pick up the tab state.
	if authoring:
		tree.call_deferred("call_group", "navigation_markers", "_apply_authoring_visibility", true)
	else:
		tree.call_deferred("call_group", "navigation_markers", "_apply_authoring_visibility", false)


static func prepare_placed_entity(entity: Node, show_markers: bool = true) -> void:
	_set_process_mode_recursive(entity, Node.PROCESS_MODE_DISABLED)
	_apply_marker_visibility(entity, show_markers)


static func _set_navigation_markers_visible(tree: SceneTree, visible: bool) -> void:
	for node in tree.get_nodes_in_group("navigation_markers"):
		_apply_marker_visibility(node, visible)


static func _apply_marker_visibility(node: Node, visible: bool) -> void:
	if not is_instance_valid(node) or not node is CanvasItem:
		return
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
