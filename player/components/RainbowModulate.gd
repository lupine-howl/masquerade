class_name RainbowModulator
extends Node

## The target node whose color modulation will cycle through the spectrum.
@export var target_node: CanvasItem

## Speed of the color shift. Higher values make it transition faster.
@export var rainbow_speed: float = 0.2

## Color saturation (0.0 = grayscale, 1.0 = fully vibrant).
@export_range(0.0, 1.0) var saturation: float = 0.9

## Color brightness value (0.0 = pure black, 1.0 = full brightness).
@export_range(0.0, 1.0) var brightness: float = 1.0

var _hue_timer: float = 0.0

func _process(delta: float) -> void:
	if not target_node:
		return
		
	# Advance and loop the hue tracker between 0.0 and 1.0
	_hue_timer = fmod(_hue_timer + (delta * rainbow_speed), 1.0)
	
	# Apply the cycling HSV color directly to the selected target
	target_node.modulate = Color.from_hsv(_hue_timer, saturation, brightness)
