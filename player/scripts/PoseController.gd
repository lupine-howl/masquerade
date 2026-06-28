extends Node2D

var active_marker: Node2D = null

# Drag your HUD node into this export variable in the Inspector!
@export var pose_hud: CanvasLayer 

func _ready() -> void:
	for child in get_children():
		if child.has_signal("clicked_on_marker"):
			child.clicked_on_marker.connect(_on_marker_selected)
			
			# 🆕 Listen for the drop event to auto-save!
			if child.has_signal("drag_dropped"):
				child.drag_dropped.connect(_on_marker_dropped)
				
			child.set_hud_visible(false)

func _on_marker_dropped(marker: Node2D) -> void:
	# Tell the HUD to bake the pose into the timeline instantly
	if pose_hud and pose_hud.has_method("auto_save_pose"):
		pose_hud.auto_save_pose(marker)

func _on_marker_selected(selected_marker: Node2D) -> void:
	if active_marker == selected_marker:
		return
		
	active_marker = selected_marker
	
	# Tell the HUD to display this marker's data!
	if pose_hud:
		pose_hud.set_active_marker(active_marker)
	
	for child in get_children():
		if child.has_method("set_hud_visible"):
			child.set_hud_visible(child == active_marker)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		active_marker = null
		
		# Clear the HUD!
		if pose_hud:
			pose_hud.set_active_marker(null)
			
		for child in get_children():
			if child.has_method("set_hud_visible"):
				child.set_hud_visible(false)
