extends Area2D
class_name HazardDetector

# --- SIGNALS ---
# We emit these so the Player (or any other script) can react instantly
signal hazard_touched
signal ladder_state_changed(is_on_ladder: bool)
signal water_state_changed(is_submerged: bool)

# --- TRACKING VARIABLES ---
var _active_ladders: int = 0
var _active_water_zones: int = 0

func _ready() -> void:
	# Connect Godot's built-in Area2D signals to our custom functions
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	
	# If your hazards/water are PhysicsBodies (like TileMaps) instead of Areas, 
	# you need to monitor bodies as well:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# --- AREA DETECTIONS ---
func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("hazards"):
		hazard_touched.emit()
		
	elif area.is_in_group("ladders"):
		_active_ladders += 1
		if _active_ladders == 1: # Just stepped onto the first ladder piece
			ladder_state_changed.emit(true)

func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("ladders"):
		_active_ladders = max(0, _active_ladders - 1)
		if _active_ladders == 0: # Stepped off the last ladder piece
			ladder_state_changed.emit(false)

# --- BODY DETECTIONS (For TileMaps) ---
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("hazards"):
		hazard_touched.emit()
	
	# Example for Water TileMaps
	elif body is TileMapLayer and body.is_in_group("water"):
		_active_water_zones += 1
		if _active_water_zones == 1:
			water_state_changed.emit(true)

func _on_body_exited(body: Node2D) -> void:
	if body is TileMapLayer and body.is_in_group("water"):
		_active_water_zones = max(0, _active_water_zones - 1)
		if _active_water_zones == 0:
			water_state_changed.emit(false)

# --- PUBLIC GETTERS ---
# Helpful if the player state machine just needs to check the current status
func is_on_ladder() -> bool:
	return _active_ladders > 0

func is_submerged() -> bool:
	return _active_water_zones > 0
