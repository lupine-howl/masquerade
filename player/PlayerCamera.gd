extends Camera2D

# How fast the camera zooms in/out
@export var zoom_speed : float = 0.1
@export var min_zoom : float = 0.1
@export var max_zoom : float = 50.0
@export var zoom_smoothing : float = 0.2

var target_zoom : Vector2
var is_dragging : bool = false

func _ready():
	target_zoom = zoom

func _process(_delta):
	# Smoothly interpolate the zoom
	zoom = zoom.lerp(target_zoom, zoom_smoothing)

func _input(event):
	# 1. Handle Dragging State
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			is_dragging = event.pressed
			
		# 2. Handle Zoom Inputs
		elif event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				target_zoom += Vector2(zoom_speed, zoom_speed)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				target_zoom -= Vector2(zoom_speed, zoom_speed)
			
			target_zoom.x = clamp(target_zoom.x, min_zoom, max_zoom)
			target_zoom.y = clamp(target_zoom.y, min_zoom, max_zoom)

	# 3. Handle Mouse Movement
	if event is InputEventMouseMotion and is_dragging:
		# Use global_position to avoid parent transform lag
		# Use the viewport's canvas transform scale for perfect 1:1 mapping
		global_position -= event.relative / get_viewport().get_canvas_transform().get_scale()
