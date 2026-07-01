@tool
extends Node2D

@export_group("Crosshair Settings")
@export var color: Color = Color.WHITE
@export var line_width: float = 2.0
@export var crosshair_length: float = 1000.0

@export_group("Grid Settings")
@export var show_grid: bool = true
@export var grid_spacing: float = 100.0
@export var grid_color: Color = Color(0.5, 0.5, 0.5, 0.5) # Semi-transparent grey
@export var grid_width: float = 1.0

func _draw() -> void:
	# 1. Draw the Main Crosshair
	draw_line(Vector2(-crosshair_length, 0), Vector2(crosshair_length, 0), color, line_width)
	draw_line(Vector2(0, -crosshair_length), Vector2(0, crosshair_length), color, line_width)
	
	# 2. Draw Gridlines
	if show_grid and grid_spacing > 0:
		var num_steps = int(crosshair_length / grid_spacing)
		
		for i in range(1, num_steps + 1):
			var offset = i * grid_spacing
			
			# Draw vertical grid lines (positive and negative)
			draw_line(Vector2(offset, -crosshair_length), Vector2(offset, crosshair_length), grid_color, grid_width)
			draw_line(Vector2(-offset, -crosshair_length), Vector2(-offset, crosshair_length), grid_color, grid_width)
			
			# Draw horizontal grid lines (positive and negative)
			draw_line(Vector2(-crosshair_length, offset), Vector2(crosshair_length, offset), grid_color, grid_width)
			draw_line(Vector2(-crosshair_length, -offset), Vector2(crosshair_length, -offset), grid_color, grid_width)

func _process(_delta: float) -> void:
	# Necessary for @tool to update in the editor when you change exported values
	if Engine.is_editor_hint():
		queue_redraw()
