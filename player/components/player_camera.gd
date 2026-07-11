extends Camera2D

@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.1
@export var max_zoom: float = 50.0
@export var zoom_smoothing: float = 0.2

var target_zoom: Vector2
var _ctrl_panning: bool = false


func _ready() -> void:
	target_zoom = zoom


func _process(_delta: float) -> void:
	zoom = zoom.lerp(target_zoom, zoom_smoothing)


func _input(event: InputEvent) -> void:
	var ctrl_held := Input.is_key_pressed(KEY_CTRL)

	if event is InputEventMouseButton:
		if ctrl_held:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_ctrl_panning = event.pressed
			elif event.is_pressed():
				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					_apply_zoom(zoom_speed)
				elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					_apply_zoom(-zoom_speed)

	if event is InputEventMouseMotion and _ctrl_panning and ctrl_held:
		global_position -= event.relative / get_viewport().get_canvas_transform().get_scale()


func _apply_zoom(delta: float) -> void:
	target_zoom += Vector2(delta, delta)
	target_zoom.x = clamp(target_zoom.x, min_zoom, max_zoom)
	target_zoom.y = clamp(target_zoom.y, min_zoom, max_zoom)
